class FlagPolicy < ApplicationPolicy
  # The flag has no workspace of its own until saved, so the flagged item's community is checked here.
  def create?
    membership.present? && record.flagger_id == user.id && record.flagged_memory.workspace_id == Current.workspace.id &&
      record.flagged_author != user && record.flaggable.class.visible_to(user).exists?(record.flaggable_id)
  end

  def resolve?
    membership.present? && record.open? && record.handled_by?(user)
  end

  alias_method :hide_now?, :resolve?
end
