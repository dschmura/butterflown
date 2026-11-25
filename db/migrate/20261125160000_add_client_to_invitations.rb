class AddClientToInvitations < ActiveRecord::Migration[8.1]
  # A client invite was marked by a non-blank company_name; an explicit flag lets that field go.
  def up
    add_column :invitations, :client, :boolean, default: false, null: false
    execute "UPDATE invitations SET client = TRUE WHERE company_name IS NOT NULL"
  end

  def down
    remove_column :invitations, :client
  end
end
