module KubernetesPlus
  class NamespacedCluster
    attr_reader :kubernetes_cluster
    attr_reader :namespace

    def self.build_from_deploy_group(deploy_group)
      new(deploy_group.kubernetes_cluster, deploy_group.kubernetes_namespace)
    end

    def initialize(kubernetes_cluster, namespace)
      @kubernetes_cluster = kubernetes_cluster
      @namespace = namespace
    end

    def get_service(name)
      Service.new(self, @kubernetes_cluster.client.get_service(name, @namespace))
    end

    def get_pods(options = {})
      @kubernetes_cluster.client.get_pods(options.merge(namespace: @namespace)).map do |pod|
        Pod.new(self, pod)
      end
    end

    def get_config_map(name)
      @kubernetes_cluster.client.get_config_map(name, @namespace)
    end

  end
end
