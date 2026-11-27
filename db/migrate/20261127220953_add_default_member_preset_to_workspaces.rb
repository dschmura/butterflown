class AddDefaultMemberPresetToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :default_member_preset, :string, null: false, default: "contributor"
    add_check_constraint :workspaces,
      "default_member_preset IN ('contributor','participant','reader')",
      name: "workspaces_default_member_preset_valid"
  end
end
