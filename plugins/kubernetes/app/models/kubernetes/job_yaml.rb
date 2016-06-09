module Kubernetes
  class JobYaml
    JOB = 'Job'.freeze

    def initialize(job_doc)
      @doc = job_doc
    end

    def to_hash
      @job_hash ||= begin
        set_namespace
        set_generate_name
        # set_spec_template_metadata
        set_docker_image
        # set_resource_usage
        set_secret_sidecar if ENV.fetch("SECRET_SIDECAR_IMAGE", false)
        set_env

        hash = template.to_hash
        Rails.logger.info "Created Kubernetes hash: #{hash.to_json}"
        hash
      end
    end

    def resource_name
      template.kind.underscore
    end

    private

    def template
      @template ||= begin
        sections = YAML.load_stream(@doc.raw_template, @doc.template_name)
        if sections.size != 1
          raise(
            Samson::Hooks::UserError,
            "Template #{@doc.template_name} has #{sections.size} sections, currently having 1 section is valid."
          )
        elsif sections.first['kind'] != JOB
          raise(
            Samson::Hooks::UserError,
            "Template #{@doc.template_name} doesn't have a 'Job' section."
          )
        else
          RecursiveOpenStruct.new(sections.first, recurse_over_arrays: true)
        end
      end
    end

    def set_namespace
      template.metadata.namespace = @doc.deploy_group.kubernetes_namespace
    end

    def set_generate_name
      project_name = @doc.kubernetes_task.project.name
      task_name    = @doc.kubernetes_task.name
      template.metadata.generateName = "#{project_name}-#{task_name}-"
    end

    # Sets the labels for each new Pod.
    # Adding the Release ID to allow us to track the progress of a new release from the UI.
    # def set_spec_template_metadata
    #   release_doc_metadata.each do |key, value|
    #     template.spec.template.metadata.labels[key] ||= value.to_s
    #   end
    # end

    # have to match Kubernetes::Release#clients selector
    # TODO: dry
    def release_doc_metadata
      @release_doc_metadata ||= begin
        # release = @doc.kubernetes_release
        # task = @doc.kubernetes_task
        deploy_group = @doc.deploy_group
        build = @doc.build

        # release.pod_selector(deploy_group).merge(
          # deploy_id: release.deploy_id,
          # project_id: release.project_id,
          # task_id: task.id,
          {
            deploy_group: deploy_group.env_value.parameterize,
            revision: build.git_sha,
            tag: build.git_ref.parameterize
          }
        # )
      end
    end

    def set_resource_usage
      container.resources = {
        limits: { cpu: @doc.cpu.to_f, memory: "#{@doc.ram}Mi" }
      }
    end

    def set_docker_image
      docker_path = @doc.build.docker_repo_digest || "#{@doc.build.project.docker_repo}:#{@doc.build.docker_ref}"
      # Assume first container is one we want to update docker image in
      container.image = docker_path
    end

    # helpful env vars, also useful for log tagging
    def set_env
      env = (container.env || [])

      # static data
      metadata = release_doc_metadata
      [:REVISION, :TAG, :DEPLOY_GROUP].each do |k|
        env << {name: k, value: metadata.fetch(k.downcase).to_s}
      end

      [:PROJECT, :TASK].each do |k|
        env << {name: k, value: template.metadata.labels.send(k.downcase).to_s}
      end

      # dynamic lookups for unknown things during deploy
      {
        POD_NAME: 'metadata.name',
        POD_NAMESPACE: 'metadata.namespace',
        POD_IP: 'status.podIP'
      }.each do |k, v|
        env << {
         name: k,
         valueFrom: {fieldRef: {fieldPath: v}}
       }
      end

      container.env = env
    end

    def container
      @container ||= begin
        containers = template.spec.template.try(:spec).try(:containers) || []
        if containers.empty?
          # TODO: support building and replacement for multiple containers
          raise(
            Samson::Hooks::UserError,
            "Template #{@doc.template_name} has #{containers.size} containers, having 1 section is valid."
          )
        end
        containers.first
      end
    end

  end
end
