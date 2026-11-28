# Who handles a removal request or flag. An admin with a block either way with anyone involved
# hears of it only when no other admin is clear. See /docs/developer/moderation.
module Moderation
  def self.admins_for(workspace, involving:)
    involved_ids = involving.compact.map(&:id)
    admins = workspace.memberships.kept.includes(:role, :user).select(&:admin?).map(&:user)
      .reject { |admin| involved_ids.include?(admin.id) }
    clear = admins.reject { |admin| Block.between(admin.id, involved_ids, workspace: workspace).exists? }
    clear.presence || admins
  end

  SIGNAL_AT = 3

  # Person id => how many current members block them, here or everywhere, from three up. Never who.
  def self.blocked_by_counts(workspace)
    members = workspace.memberships.kept.select(:user_id)
    Block.where(blocked_id: members, blocker_id: members)
      .merge(Block.where(workspace: workspace).or(Block.where(everywhere: true)))
      .group(:blocked_id).distinct.count(:blocker_id)
      .select { |_person_id, count| count >= SIGNAL_AT }
  end
end
