module KubernetesPlus
  class Pod
    attr_reader :namespaced_cluster, :pod_spec

    def initialize(namespaced_cluster, pod_spec)
      @namespaced_cluster = namespaced_cluster
      @pod_spec = pod_spec
    end

    def containers
      @containers ||= @pod_spec.spec.containers.map do |container_spec|
        Container.new(self, container_spec)
      end
    end

    def metadata
      @pod_spec.metadata
    end

    def status
      @pod_spec.status
    end

  end
end
