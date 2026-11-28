class User
  # Deleting an account is held for 30 days, then the row stays as a tombstone, so shared memories and
  # approved tags keep their credit; whatever identifies the person or signs them in goes. See /docs/developer/leaving.
  module AccountDeletion
    extend ActiveSupport::Concern

    DELETION_HELD_FOR = 30.days

    included do
      # Destroying the row would cascade away every tag they made and every tag naming them.
      before_destroy :keep_the_tombstone, prepend: true

      scope :deletion_due, ->(now: Time.current) {
        where(deleted_at: nil).where(deletion_requested_at: ..(now - DELETION_HELD_FOR))
      }
    end

    def deleted? = deleted_at.present?

    def deletion_pending? = deletion_requested_at.present? && !deleted?

    # Every sign-in and session guard asks suspended?, so a sign-in racing the deletion can't land.
    def suspended? = super || deleted?

    # Raises Membership::LastOwner, changing nothing, while they are a community's only owner.
    def request_deletion!(remove_name: false)
      transaction do
        lock!
        next if deletion_pending? || deleted?

        requested_at = Time.current
        leave_every_community(remove_name: remove_name)
        sessions.destroy_all
        update_columns(deletion_requested_at: requested_at, deletion_removes_name: remove_name)
      end
    end

    def cancel_deletion!
      transaction do
        lock!
        next unless deletion_pending?

        memberships.discarded.includes(:workspace).where(departure: "left", discarded_at: deletion_requested_at..)
          .find_each { |membership| membership.reactivate!(self_join: true) if room_to_come_back?(membership.workspace) }
        update_columns(deletion_requested_at: nil, deletion_removes_name: false)
      end
    end

    # Re-asked under the lock: a cancel between the sweep's query and this call wins.
    def complete_deletion!(now: Time.current)
      transaction do
        lock!
        next unless self.class.deletion_due(now: now).exists?(id)

        leave_every_community(remove_name: deletion_removes_name)
        Memory.where(author: self, visibility: "only_me").find_each(&:destroy!)
        scrub!(remove_name: deletion_removes_name)
      end
    end

    private

    # Like any way back in: never into a community that has closed or filled up meanwhile.
    def room_to_come_back?(workspace)
      workspace.lock!
      workspace.admittable? && !workspace.at_capacity?
    end

    def leave_every_community(remove_name:)
      memberships.includes(:workspace).find_each do |membership|
        next if membership.workspace.personal?

        if membership.kept?
          membership.leave!(remove_name: remove_name)
        elsif remove_name
          membership.update!(name_removed: true)
        end
      end
    end

    def scrub!(remove_name:)
      forget_email(email_address)
      operatorships.kept.find_each(&:revoke!)
      MemoryAccess.where(user: self).delete_all
      [ sessions, authentications, webauthn_credentials, client_accesses ].each(&:destroy_all)
      [ webauthn_challenges, reauthentication_challenges, notifications, invitation_blocks ].each(&:delete_all)
      preferences&.destroy!
      [ avatar, avatar_original ].each { |picture| picture.purge if picture.attached? }

      update_columns(
        email_address: "deleted-#{SecureRandom.uuid}@deleted.invalid",
        password_digest: nil, pending_email: nil, pending_email_token: nil, pending_email_sent_at: nil,
        webauthn_handle: nil, last_known_browsers: [], has_gravatar: false, avatar_source: "initials",
        deleted_at: Time.current, updated_at: Time.current,
        **(remove_name ? { first_name: nil, last_name: nil } : {})
      )
      personal_workspace&.update_columns(name: I18n.t("users.deleted_account.workspace_name")) if remove_name
    end

    # Nothing addressed to the old email may later join a new account to what this one left.
    def forget_email(address)
      Invitation.pending.where(email: address).find_each(&:revoke!)
      MagicLinkToken.where(email: address).delete_all
    end

    def keep_the_tombstone
      throw :abort if deleted?
    end
  end
end
