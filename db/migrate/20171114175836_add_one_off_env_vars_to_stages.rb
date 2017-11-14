class AddOneOffEnvVarsToStages < ActiveRecord::Migration[5.1]
  def change
    add_column :stages, :one_off_env_vars, :boolean, default: false, null:false
  end
end
