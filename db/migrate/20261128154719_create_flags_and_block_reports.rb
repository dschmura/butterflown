class CreateFlagsAndBlockReports < ActiveRecord::Migration[8.2]
  def change
    create_table :flags do |t|
      t.references :workspace, null: false, foreign_key: { on_delete: :cascade }
      t.references :flaggable, polymorphic: true, null: false
      t.references :flagger, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.text :reason, null: false
      t.string :outcome
      t.references :resolved_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :resolved_at
      t.timestamps

      t.index [ :flaggable_type, :flaggable_id, :flagger_id ], unique: true, name: "index_flags_one_per_flagger"
      t.index :workspace_id, where: "resolved_at IS NULL", name: "index_flags_open"
      t.check_constraint "flaggable_type IN ('Memory','MemoryResource')", name: "flags_flaggable_type_valid"
      t.check_constraint "outcome IS NULL OR outcome IN ('acted','dismissed')", name: "flags_outcome_valid"
      t.check_constraint "(outcome IS NULL) = (resolved_at IS NULL)", name: "flags_resolved_with_outcome"
    end

    create_table :block_reports do |t|
      t.references :workspace, null: false, foreign_key: { on_delete: :cascade }
      t.references :reporter, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.references :reported, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :reason, null: false
      t.text :note
      t.references :resolved_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :resolved_at
      t.timestamps

      t.index :workspace_id, where: "resolved_at IS NULL", name: "index_block_reports_open"
      t.check_constraint "reason IN ('harassment','unwanted_contact','something_they_posted','other')",
        name: "block_reports_reason_valid"
    end
  end
end
