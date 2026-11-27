class MemoryPolicy < ApplicationPolicy
  def create?
    membership.present? && membership.may_post_memories? && record.workspace.accepts_new_memories?
  end

  def update?
    authored_by_current_member?
  end

  def destroy?
    authored_by_current_member?
  end

  private

  def authored_by_current_member?
    membership.present? && record.author_id == user.id
  end
end
