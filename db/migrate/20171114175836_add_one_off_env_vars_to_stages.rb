class AddOneOffEnvVarsToStages < ActiveRecord::Migration[5.1]
  def change
    add_column :stages, :one_off_env_vars, :boolean
  end
end
