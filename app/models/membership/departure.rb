class Membership
  # How someone left a community, and what leaving does to the tags naming them. Read on every
  # deactivation, so the template's own leave and remove paths obey it. See /docs/developer/leaving.
  module Departure
    extend ActiveSupport::Concern

    class NotRemovedForCause < StandardError; end

    included do
      # Non-persisted: the reason lives in the admin-only audit row, not on the membership.
      attr_accessor :removal_reason

      enum :departure, { left: "left", removed: "removed", removed_for_cause: "removed_for_cause" },
        prefix: :departure, validate: { allow_nil: true }

      validate :removal_reason_given, if: -> { departure_removed_for_cause? && will_save_change_to_departure? }
      validate :readmitted_only_by_an_admin, if: :reactivating?

      before_save :record_departure, if: :deactivating?
      before_save :forget_departure, if: :reactivating?
      after_update :unname_pending_tags, if: :just_deactivated?
      after_update :log_removal_for_cause, :revoke_pending_invitations,
        if: -> { departure_removed_for_cause? && saved_change_to_departure? }
    end

    def leave!(remove_name: false)
      return if discarded?

      self.name_removed = remove_name
      deactivate!(removed_by: user)
    end

    # Someone who already left or was removed can still be marked, or leaving first would dodge it.
    def remove_for_cause!(by:, reason:)
      return if departure_removed_for_cause?

      self.departure = "removed_for_cause"
      self.removal_reason = reason
      if discarded?
        self.removed_by = by
        save!
      else
        deactivate!(removed_by: by)
      end
    end

    # Deletes every memory they posted here, anonymous ones too, without listing which.
    def clear_memories_for_cause!(by:)
      raise NotRemovedForCause unless departure_removed_for_cause?

      transaction do
        cleared = Memory.kept.where(workspace: workspace, author: user)
        count = cleared.update_all(discarded_at: Time.current, updated_at: Time.current)
        create_activity("membership.memories_cleared", { "count" => count, "cleared_by" => by.id })
      end
    end

    private

    def deactivating?
      will_save_change_to_discarded_at? && discarded_at.present? && discarded_at_in_database.nil?
    end

    def reactivating?
      will_save_change_to_discarded_at? && discarded_at.nil?
    end

    def removal_reason_given
      errors.add(:base, :removal_reason_required) if removal_reason.blank?
    end

    # Someone removed for cause comes back only when one of this community's admins brings them.
    def readmitted_only_by_an_admin
      return unless departure_in_database == "removed_for_cause"

      errors.add(:base, :removed_for_cause) unless workspace.memberships.kept.find_by(user: granted_by)&.admin?
    end

    def record_departure
      self.departure ||= removed_by.present? && removed_by.id == user_id ? "left" : "removed"
    end

    def forget_departure
      self.departure = nil
      self.name_removed = false
    end

    def unname_pending_tags
      now = Time.current
      Tag.pending.where(tagged_user_id: user_id)
        .where(memory_resource_id: MemoryResource.joins(:memory).where(memories: { workspace_id: workspace_id }))
        .update_all(state: "unnamed", state_changed_at: now, expires_at: nil, updated_at: now)
    end

    # An invitation sent before the removal mustn't become a way back in.
    def revoke_pending_invitations
      projects = Project.where(workspace_id: workspace_id)
      Invitation.pending.where(email: user.email_address)
        .where(invitable: workspace).or(Invitation.pending.where(email: user.email_address, invitable: projects))
        .find_each(&:revoke!)
    end

    def log_removal_for_cause
      create_activity("membership.removed_for_cause", { "reason" => removal_reason.strip, "removed_by" => removed_by&.id }.compact)
    end
  end
end
