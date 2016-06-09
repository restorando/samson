module Kubernetes
  class JobDoc < ActiveRecord::Base
    include Kubernetes::HasStatus

    self.table_name = 'kubernetes_job_docs'

    belongs_to :kubernetes_task, class_name: 'Kubernetes::Task'
    belongs_to :build
    belongs_to :deploy_group
    belongs_to :job

    validates :deploy_group, presence: true
    validates :kubernetes_task, presence: true
    validates :build, presence: true
    validates :status, presence: true, inclusion: STATUSES
    validate :validate_config_file, on: :create

    def client
      deploy_group.kubernetes_cluster.client
    end

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

    private

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
