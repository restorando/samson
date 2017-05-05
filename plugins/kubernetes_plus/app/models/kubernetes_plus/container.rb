module KubernetesPlus
  class Container
    attr_reader :pod

    def initialize(pod, container_spec)
      @pod = pod
      @container_spec = container_spec
    end

    def environment
      @environment ||= ContainerEnvironment.new(self, @container_spec.env)
    end

    def namespaced_cluster
      @pod.namespaced_cluster
    end

  end
end
