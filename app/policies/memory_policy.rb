class MemoryPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.visible_to(user)
    end
  end

  def show?
    record_in_current_workspace? && Memory.visible_to(user).exists?(record.id)
  end

  def create?
    membership.present? && membership.may_post_memories? && record.workspace.accepts_new_memories?
  end

  def update?
    authored_by_current_member?
  end

  def destroy?
    authored_by_current_member? || deletable_from_exit_page? || clearing_a_removal_for_cause?
  end

  private

  def deletable_from_exit_page?
    Memory.on_exit_page_of(user).exists?(record.id) && !author_removed_for_cause?
  end

  # Someone removed for cause can't delete what they posted; only an admin can, and not an anonymous
  # one, where the offer alone would say who wrote it.
  def clearing_a_removal_for_cause?
    can?("manage_members") && !record.anonymous? && author_removed_for_cause?
  end

  def author_removed_for_cause?
    record.workspace.memberships.exists?(user_id: record.author_id, departure: "removed_for_cause")
  end

  def authored_by_current_member?
    membership.present? && record.author_id == user.id
  end
end
