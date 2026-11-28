class CreateRemovalRequests < ActiveRecord::Migration[8.2]
  def change
    create_table :removal_requests do |t|
      t.references :workspace, null: false, foreign_key: { on_delete: :cascade }
      t.references :memory_resource, null: false, foreign_key: { on_delete: :cascade }
      t.references :requester, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.string :recipients, null: false
      t.text :reason, null: false
      t.datetime :due_at, null: false
      t.datetime :relayed_at
      t.string :outcome
      t.references :decided_by, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :decided_at
      t.timestamps

      t.index [ :memory_resource_id, :requester_id ], unique: true
      t.index [ :workspace_id, :due_at ], where: "decided_at IS NULL", name: "index_removal_requests_open_by_due"
      t.check_constraint "recipients IN ('author','admins','both')", name: "removal_requests_recipients_valid"
      t.check_constraint "outcome IS NULL OR outcome IN ('removed','changed','kept')", name: "removal_requests_outcome_valid"
      t.check_constraint "(outcome IS NULL) = (decided_at IS NULL)", name: "removal_requests_decided_with_outcome"
    end

    add_column :memory_resources, :hidden_at, :datetime
  end
end
