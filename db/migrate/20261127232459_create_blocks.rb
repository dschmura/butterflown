class CreateBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :blocks do |t|
      t.references :workspace, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :blocker, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :blocked, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.boolean :everywhere, null: false, default: false
      t.timestamps

      t.index [ :workspace_id, :blocker_id, :blocked_id ], unique: true
      t.check_constraint "blocker_id <> blocked_id", name: "blocks_not_yourself"
    end
  end
end
