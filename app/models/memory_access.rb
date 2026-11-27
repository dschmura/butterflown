# One person a memory's author named. It grants sight only while the memory is shared beyond its
# author. See /docs/developer/memory-visibility.
class MemoryAccess < ApplicationRecord
  belongs_to :memory
  belongs_to :user

  validates :user_id, uniqueness: { scope: :memory_id }
  validate :user_is_a_member

  private

  def user_is_a_member
    return if memory.nil? || user.nil?
    errors.add(:user, :not_a_member) unless memory.workspace.memberships.kept.exists?(user: user)
  end
end
