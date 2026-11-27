# One member blocking another. Silent: the blocked person is never told and admins never list it,
# so it is never Trackable. See /docs/developer/blocks.
class Block < ApplicationRecord
  include Tenanted

  belongs_to :blocker, class_name: "User"
  belongs_to :blocked, class_name: "User"

  validates :blocked_id, uniqueness: { scope: [ :workspace_id, :blocker_id ] }
  validate :not_yourself
  validate :both_are_members, on: :create

  private

  def not_yourself
    errors.add(:blocked, :yourself) if blocker_id.present? && blocker_id == blocked_id
  end

  def both_are_members
    return if workspace.nil?

    members = workspace.memberships.kept
    errors.add(:blocker, :not_a_member) unless members.exists?(user_id: blocker_id)
    errors.add(:blocked, :not_a_member) unless members.exists?(user_id: blocked_id)
  end
end
