class BlockPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      user ? scope.where(blocker: user) : scope.none
    end
  end

  def create?
    membership.present? && record.blocker_id == user.id
  end

  def show?
    own_block?
  end

  def update?
    own_block?
  end

  def destroy?
    own_block?
  end

  private

  # Not tied to membership: a blocker who has left must still be able to see and lift their block.
  def own_block?
    user.present? && record.blocker_id == user.id
  end
end
