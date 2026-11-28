class AllowRemovalForCause < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :memberships, "departure IN ('left','removed')", name: "memberships_departure_valid"
    add_check_constraint :memberships, "departure IN ('left','removed','removed_for_cause')", name: "memberships_departure_valid"
  end
end
