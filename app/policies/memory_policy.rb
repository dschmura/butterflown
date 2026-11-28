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
    authored_by_current_member? || Memory.on_exit_page_of(user).exists?(record.id)
  end

  private

  def authored_by_current_member?
    membership.present? && record.author_id == user.id
  end
end
