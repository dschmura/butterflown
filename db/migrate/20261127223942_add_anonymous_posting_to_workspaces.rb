class AddAnonymousPostingToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :anonymous_posting, :boolean, null: false, default: false
  end
end
