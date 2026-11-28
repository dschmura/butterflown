class AddTagSettingToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :tag_setting, :string, null: false, default: "approve"
    add_check_constraint :memberships, "tag_setting IN ('approve','okay')", name: "memberships_tag_setting_valid"
  end
end
