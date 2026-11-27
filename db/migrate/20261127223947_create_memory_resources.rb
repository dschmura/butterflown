class CreateMemoryResources < ActiveRecord::Migration[8.1]
  def change
    create_table :memory_resources do |t|
      t.references :memory, null: false, foreign_key: true
      t.references :contributor, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :kind, null: false
      t.text :body
      t.string :content_warning
      t.timestamps

      t.check_constraint "kind IN ('written_reflection','photo')", name: "memory_resources_kind_valid"
    end
  end
end
