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
end
