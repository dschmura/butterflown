# Reporting is asked of a Block (the blocker's own); resolving, of a BlockReport.
class BlockReportPolicy < ApplicationPolicy
  def report?
    membership.present? && record.blocker_id == user.id
  end

  def resolve?
    membership.present? && record.open? && record.handled_by?(user)
  end
end
