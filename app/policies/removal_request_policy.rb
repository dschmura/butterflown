class RemovalRequestPolicy < ApplicationPolicy
  # The request has no workspace of its own until saved, so the resource's community is checked here.
  def create?
    membership.present? && record.memory_resource.memory.workspace_id == Current.workspace.id &&
      record.requester_id == user.id && record.memory_resource.contributor_id != user.id &&
      MemoryResource.visible_to(user).exists?(record.memory_resource_id)
  end

  # Admins answer whenever a request reaches them; the author answers one sent only to them.
  def decide?
    return false unless membership.present? && record.open?

    record.answered_by_admins? ? record.handled_by?(user) : record.memory_resource.contributor_id == user.id
  end

  def hide_now?
    membership.present? && record.open? && record.handled_by?(user)
  end

  def relay?
    hide_now? && record.anonymous_author? && record.relayed_at.nil?
  end
end
