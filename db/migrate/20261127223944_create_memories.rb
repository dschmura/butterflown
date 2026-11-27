class CreateMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :memories do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.boolean :anonymous, null: false, default: false
      t.string :visibility, null: false, default: "only_me"
      t.string :comment_rule, null: false, default: "viewers"
      t.string :reflect_rule, null: false, default: "viewers"
      t.string :tag_rule, null: false, default: "viewers"
      t.boolean :visible_to_guests, null: false, default: false
      t.datetime :discarded_at
      t.timestamps

      t.index [ :workspace_id, :visibility ]
      t.index :discarded_at
      t.check_constraint "visibility IN ('only_me','specific_people','community')", name: "memories_visibility_valid"
      t.check_constraint "comment_rule IN ('viewers','author')", name: "memories_comment_rule_valid"
      t.check_constraint "reflect_rule IN ('viewers','author')", name: "memories_reflect_rule_valid"
      t.check_constraint "tag_rule IN ('viewers','author')", name: "memories_tag_rule_valid"
    end
  end
end
