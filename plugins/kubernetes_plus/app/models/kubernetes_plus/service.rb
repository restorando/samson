module KubernetesPlus
  class Service
    attr_accessor :namespaced_cluster

    def initialize(namespaced_cluster, service_spec)
      @namespaced_cluster = namespaced_cluster
      @service_spec = service_spec
    end

    def pods
      @namespaced_cluster.get_pods(label_selector: pods_label_selector)
    end

    private

    def pods_label_selector
      @service_spec.spec.selector.to_hash.map {|key, value| "#{key}=#{value}" }.join(',')
    end

  end
end
