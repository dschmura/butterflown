# Deletes the accounts whose 30-day hold is up. See /docs/developer/leaving.
class AccountDeletionSweepJob < ApplicationJob
  queue_as :low

  def perform
    User.deletion_due.find_each do |user|
      user.complete_deletion!
    rescue Membership::LastOwner => error
      # Made a community's only owner during the hold; it stays pending and is retried tomorrow.
      Rails.error.report(error, handled: true, context: { user_id: user.id })
    end
  end
end
