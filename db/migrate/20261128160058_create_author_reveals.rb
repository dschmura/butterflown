class CreateAuthorReveals < ActiveRecord::Migration[8.2]
  def change
    create_table :author_reveals do |t|
      t.references :workspace, null: false, foreign_key: { on_delete: :cascade }
      t.references :memory, null: false, foreign_key: { on_delete: :cascade }
      t.references :revealed_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :reason, null: false
      t.timestamps
    end
  end
end
