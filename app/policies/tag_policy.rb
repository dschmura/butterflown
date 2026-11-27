class TagPolicy < ApplicationPolicy
  def create?
    return false unless user && record.tagger_id == user.id && in_the_memorys_community?
    return false unless membership&.may_tag? && Memory.visible_to(user).exists?(memory.id)
    return false if memory.tag_rule == "author" && !authored?

    record.tagged_user.nil? || authored? || Memory.visible_to(record.tagged_user).exists?(memory.id)
  end

  def update?
    user.present? && record.tagged_user_id == user.id
  end

  def destroy?
    user.present? && (record.tagger_id == user.id || authored?)
  end

  private

  def memory
    record.memory_resource.memory
  end

  def authored?
    memory.author_id == user&.id
  end

  # A tag carries no workspace_id, so ApplicationPolicy's cross-workspace guard can't see it.
  def in_the_memorys_community?
    memory.workspace_id == Current.workspace&.id
  end
end
