class User
  # Deleting an account keeps the row as a tombstone, so shared memories and approved tags keep their
  # credit; whatever identifies the person or signs them in goes. See /docs/developer/leaving.
  module AccountDeletion
    extend ActiveSupport::Concern

    included do
      # Destroying the row would cascade away every tag they made and every tag naming them.
      before_destroy :keep_the_tombstone, prepend: true
    end

    def deleted? = deleted_at.present?

    # Every sign-in and session guard asks suspended?, so a sign-in racing the deletion can't land.
    def suspended? = super || deleted?

    # Raises Membership::LastOwner, changing nothing, while they are a community's only owner.
    def delete_account!(remove_name: false)
      transaction do
        lock!
        next if deleted?

        leave_every_community(remove_name: remove_name)
        Memory.where(author: self, visibility: "only_me").find_each(&:destroy!)
        scrub!(remove_name: remove_name)
      end
    end

    private

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
