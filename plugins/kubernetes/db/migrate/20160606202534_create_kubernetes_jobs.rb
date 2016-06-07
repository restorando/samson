class CreateKubernetesJobs < ActiveRecord::Migration
  def change
    create_table :kubernetes_jobs do |t|
      t.references :stage, null: false, index: true
      t.references :kubernetes_task, null: false, index: true
      t.references :user, null: false, index: true
      t.references :build
      t.string :status, default: "created"
      t.string :commit
      t.string :tag
      t.text :output
      t.datetime :started_at
      t.timestamps
    end
  end
end
