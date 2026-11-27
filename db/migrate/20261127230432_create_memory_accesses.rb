class CreateMemoryAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :memory_accesses do |t|
      t.references :memory, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps

      t.index [ :memory_id, :user_id ], unique: true
    end
  end
end
