# executes a deploy and writes log to job output
# finishes when cluster is "Ready"
module Kubernetes
  class JobExecutor
    TICK = 2.seconds
    RESTARTED = "Restarted".freeze

    def initialize(output, job:)
      @output = output
      @job = job
    end

    def pid
      "Kubernetes-job-#{object_id}"
    end

    def stop!(_signal)
      @stopped = true
    end

    def execute!(*)
      build = find_or_create_build
      return false if stopped?
      job_docs = create_job_docs(build)
      run_job_docs(job_docs)
      success = wait_for_job_to_finish(job_docs)
      show_failure_cause(job_docs) unless success
      success
    end

    private

    def wait_for_job_to_finish(job_docs)
      start = Time.now
      # stable_ticks = CHECK_STABLE / TICK

      # loop do
      #   return false if stopped?
      #
      #   statuses = pod_statuses(release)
      #
      #   if @testing_for_stability
      #     if statuses.all?(&:live)
      #       @testing_for_stability += 1
      #       @output.puts "Stable #{@testing_for_stability}/#{stable_ticks}"
      #       if stable_ticks == @testing_for_stability
      #         @output.puts "SUCCESS"
      #         return true
      #       end
      #     else
      #       print_statuses(statuses)
      #       unstable!
      #       return false
      #     end
      #   else
      #     print_statuses(statuses)
      #     if statuses.all?(&:live)
      #       @output.puts "READY, starting stability test"
      #       @testing_for_stability = 0
      #     elsif statuses.map(&:details).include?(RESTARTED)
      #       unstable!
      #       return false
      #     elsif start + WAIT_FOR_LIVE < Time.now
      #       @output.puts "TIMEOUT, pods took too long to get live"
      #       return false
      #     end
      #   end
      #
      #   sleep TICK
      # end
      true
    end

    def pod_statuses(release)
      pods = release.clients.flat_map { |client, query| fetch_pods(client, query) }
      job_docs.flat_map { |release_doc| release_statuses(pods, release_doc) }
    end

    def fetch_pods(client, query)
      client.get_pods(query).map! { |p| Kubernetes::Api::Pod.new(p) }
    end

    def show_failure_cause(job_docs)
      bad_pods(job_docs).each do |pod, client, deploy_group|
        @output.puts "\n#{deploy_group.name} pod #{pod.name}:"
        print_events(client, pod)
        @output.puts
        print_logs(client, pod)
      end
    end

    # logs - container fails to boot
    def print_logs(client, pod)
      @output.puts "LOGS:"

      pod.containers.map(&:name).each do |container|
        @output.puts "Container #{container}" if pod.containers.size > 1

        logs = begin
          client.get_pod_log(pod.name, pod.namespace, previous: pod.restarted?, container: container)
        rescue KubeException
          begin
            client.get_pod_log(pod.name, pod.namespace, previous: !pod.restarted?, container: container)
          rescue KubeException
            "No logs found"
          end
        end
        @output.puts logs
      end
    end

    # events - not enough cpu/ram available
    def print_events(client, pod)
      @output.puts "EVENTS:"
      events = client.get_events(
        namespace: pod.namespace,
        field_selector: "involvedObject.name=#{pod.name}"
      )
      events.uniq! { |e| e.message.split("\n").sort }
      events.each { |e| @output.puts "#{e.reason}: #{e.message}" }
    end

    def bad_pods(job_docs)
      # job_docs.clients.flat_map do |client, query, deploy_group|
      #   bad_pods = fetch_pods(client, query).select { |p| p.restarted? || !p.live? }
      #   bad_pods.map { |p| [p, client, deploy_group] }
      # end
    end

    def unstable!
      @output.puts "UNSTABLE - service is restarting"
    end

    def stopped?
      if @stopped
        @output.puts "STOPPED"
        true
      end
    end

    def release_statuses(pods, release_doc)
      group = release_doc.deploy_group
      role = release_doc.kubernetes_role

      pods = pods.select { |pod| pod.role_id == role.id && pod.deploy_group_id == group.id }

      statuses = if pods.empty?
        [[false, "Missing"]]
      else
        pods.map do |pod|
          if pod.live?
            if pod.restarted?
              [false, RESTARTED]
            else
              [true, "Live"]
            end
          else
            [false, "Waiting (#{pod.phase}, not Ready)"]
          end
        end
      end

      statuses.map do |live, details|
        ReleaseStatus.new(live, details, role.name, group.name)
      end
    end

    def print_statuses(status_groups)
      status_groups.group_by(&:group).each do |group, statuses|
        @output.puts "#{group}:"
        statuses.each do |status|
          @output.puts "  #{status.role}: #{status.details}"
        end
      end
    end

    def find_or_create_build
      build = Build.find_by_git_sha(@job.commit) || create_build
      wait_for_build(build)
      ensure_build_is_successful(build) unless @stopped
      build
    end

    def wait_for_build(build)
      if !build.docker_repo_digest && build.docker_build_job.try(:running?)
        @output.puts("Waiting for Build #{build.url} to finish.")
        loop do
          break if @stopped
          sleep TICK
          break if build.docker_build_job(:reload).finished?
        end
      end
      build.reload
    end

    def create_build
      @output.puts("Creating Build for #{@job.commit}.")

      build = Build.create!(
        git_ref: @job.commit,
        creator: @job.user,
        project: @job.project,
        label: "Automated build triggered via Job ##{@job.id}"
      )
      DockerBuilderService.new(build).run!(push: true)
      build
    end

    def ensure_build_is_successful(build)
      if build.docker_repo_digest
        @output.puts("Build #{build.url} is looking good!")
      elsif build_job = build.docker_build_job
        raise Samson::Hooks::UserError, "Build #{build.url} is #{build_job.status}, rerun it manually."
      else
        raise Samson::Hooks::UserError, "Build #{build.url} was created but never ran, run it manually."
      end
    end

    # create a release, storing all the configuration
    def create_job_docs(build)
      job_docs = @job.stage.deploy_groups.map do |deploy_group|
        @job.job_docs.create(
          kubernetes_task: @job.kubernetes_task,
          build_id: build.id,
          deploy_group_id: deploy_group.id,
        )
      end

      unless job_docs.all?(&:persisted?)
        raise Samson::Hooks::UserError, "Failed to create job: #{job_docs.map(&:errors).map(&:full_messages).inspect}"
      end

      job_docs.each do |job_doc|
        @output.puts("Created job doc #{job_doc.id}")
      end

      job_docs
    end

    def run_job_docs(job_docs)
      job_docs.each(&:run)
    end
  end
end
