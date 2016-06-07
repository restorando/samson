class CreateKubernetesJobDocs < ActiveRecord::Migration
  def change
    create_table :kubernetes_job_docs do |t|
      t.references :kubernetes_task, null: false, index: true
      t.references :job, null: false, index: true
      t.references :build, null: false, index: true
      t.references :deploy_group, null: false, index: true
      t.string :status, default: "created"
      t.timestamps
    end
  end
end
