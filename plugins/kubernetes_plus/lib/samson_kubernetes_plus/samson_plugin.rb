# frozen_string_literal: true

module SamsonKubernetesPlus
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_show, "samson_kubernetes_plus/stage_show"
