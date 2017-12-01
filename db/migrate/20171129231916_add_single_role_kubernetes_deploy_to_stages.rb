class AddSingleRoleKubernetesDeployToStages < ActiveRecord::Migration[5.1]
  def change
    add_column :stages, :single_role_kubernetes_deploy, :boolean, default: false, null:false
  end
end
