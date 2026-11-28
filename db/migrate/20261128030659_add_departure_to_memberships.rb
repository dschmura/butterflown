class AddDepartureToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :departure, :string
    add_column :memberships, :name_removed, :boolean, null: false, default: false
    add_check_constraint :memberships, "departure IN ('left','removed')", name: "memberships_departure_valid"
    add_check_constraint :memberships, "departure IS NULL OR discarded_at IS NOT NULL", name: "memberships_departure_only_when_gone"
  end
end
