class AddPresetToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :preset, :string, null: false, default: "contributor"
    add_check_constraint :memberships,
      "preset IN ('contributor','participant','reader')",
      name: "memberships_preset_valid"
  end
end
