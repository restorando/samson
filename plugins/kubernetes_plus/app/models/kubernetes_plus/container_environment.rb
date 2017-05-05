module KubernetesPlus
  class ContainerEnvironment
    include Enumerable

    def initialize(container, environment_spec)
      @container = container
      @environment = environment_spec.each_with_object({}) do |value, hash|
        hash[value[:name]] = value.to_hash
      end
    end

    def each
      @environment.each do |key, value|
        yield key, self[key]
      end
    end

    def [](key)
      extract_value(@environment[key])
    end

    def to_s
      map { |k, v| "#{k}=#{v.shellescape}" }.join("\n")
    end

    def namespaced_cluster
      @container.namespaced_cluster
    end

    private

    def extract_value(env_value)
      return env_value[:value] if env_value.key?(:value)

      source = env_value[:valueFrom]
      if source.key?(:configMapKeyRef)
        fetch_value_from_config_map_ref(source[:configMapKeyRef])
      elsif source.key?(:fieldRef)
        @container.pod.pod_spec.dig(*source[:fieldRef][:fieldPath].split(".").map(&:to_sym))
      elsif source.key?(:secretKeyRef)
        "Secret value"
      else
        raise "Unsupported source #{source}"
      end
    end

    def fetch_value_from_config_map_ref(config_map_ref)
      namespaced_cluster.get_config_map(config_map_ref[:name]).data[config_map_ref[:key]]
    end

  end
end
