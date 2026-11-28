class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :memory_resource, null: false, foreign_key: { on_delete: :cascade }
      t.references :tagged_user, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :typed_name
      t.references :tagger, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :state, null: false
      t.datetime :state_changed_at, null: false
      t.datetime :expires_at
      t.timestamps

      t.index [ :memory_resource_id, :tagged_user_id ], unique: true, where: "tagged_user_id IS NOT NULL"
      t.index [ :state, :expires_at ]
      t.check_constraint "state IN ('pending','approved','unnamed')", name: "tags_state_valid"
      t.check_constraint "(tagged_user_id IS NULL) <> (typed_name IS NULL)", name: "tags_person_or_name"
    end
  end
end
