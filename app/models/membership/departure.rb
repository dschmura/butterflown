class Membership
  # How someone left a community, and what leaving does to the tags naming them. Read on every
  # deactivation, so the template's own leave and remove paths obey it. See /docs/developer/leaving.
  module Departure
    extend ActiveSupport::Concern

    included do
      enum :departure, { left: "left", removed: "removed" },
        prefix: :departure, validate: { allow_nil: true }

      before_save :record_departure, if: :deactivating?
      before_save :forget_departure, if: :reactivating?
      after_update :unname_pending_tags, if: :just_deactivated?
    end

    def leave!(remove_name: false)
      return if discarded?

      self.name_removed = remove_name
      deactivate!(removed_by: user)
    end

    private

    def deactivating?
      will_save_change_to_discarded_at? && discarded_at.present? && discarded_at_in_database.nil?
    end

    def reactivating?
      will_save_change_to_discarded_at? && discarded_at.nil?
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
  end
end
