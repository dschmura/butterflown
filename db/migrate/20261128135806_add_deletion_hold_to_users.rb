class AddDeletionHoldToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :deletion_requested_at, :datetime
    add_column :users, :deletion_removes_name, :boolean, default: false, null: false
    add_index :users, :deletion_requested_at, where: "deletion_requested_at IS NOT NULL AND deleted_at IS NULL"
  end
end
