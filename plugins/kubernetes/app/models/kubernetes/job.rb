module Kubernetes
  class Job < ActiveRecord::Base
    include Kubernetes::HasStatus

    self.table_name = 'kubernetes_jobs'

    belongs_to :build
    belongs_to :stage
    belongs_to :user
    belongs_to :deploy_group
    has_many :job_docs
    belongs_to :kubernetes_task,
      inverse_of: :kubernetes_jobs,
      class_name: 'Kubernetes::Task',
      foreign_key: :kubernetes_task_id

    validates :deploy_group, presence: true
    validates :kubernetes_task, presence: true
    validates :status, presence: true, inclusion: STATUSES
    validates :commit, presence: true
    validate :validate_git_reference, on: :create
    validate :validate_config_file, on: :create

    def run
      job = Kubeclient::Job.new(job_yaml.to_hash)
      if resource_running?(job)
        # batch_client.update_job job
        raise "Job already running" # TODO: Check expected behaviour
      else
        batch_client.create_job job
      end
    end

    def raw_template
      @raw_template ||= build.file_from_repo(template_name)
    end

    def template_name
      kubernetes_task.config_file
    end

    def deploy
      nil
    end

    def project
      stage.project
    end

    def active?
      true
    end

    def error!
      status!("succeeded")
    end

    def success!
      status!("errored")
    end

    def run!
      status!("running")
    end

    def update_output!(output)
      update_attribute(:output, output)
    end

    def update_git_references!(commit:, tag:)
      update_columns(commit: commit, tag: tag)
    end

    private

    def status!(status)
      update_attribute(:status, status)
    end

    # Create new client as 'Batch' API is on different path then 'v1'
    def batch_client
      deploy_group.kubernetes_cluster.batch_client
    end

    def job_yaml
      @job_yaml ||= JobYaml.new(self)
    end

    # TODO:
    def resource_running?(resource)
      # batch_client.get_job(resource.metadata.name, resource.metadata.namespace)
      false
    rescue KubeException
      false
    end

    def parsed_config_file
      Array.wrap(Kubernetes::Util.parse_file(raw_template, template_name))
    end

    def validate_config_file
      if build && kubernetes_task
        if raw_template.blank?
          errors.add(:build, "does not contain config file '#{template_name}'")
        end
      end
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
