class MemoryResource < ApplicationRecord
  # Who may see a resource: whoever sees its memory, less what moderation took away.
  # See /docs/developer/moderation.
  module Visibility
    extend ActiveSupport::Concern

    NOT_HIDDEN = "memory_resources.hidden_at IS NULL OR memory_resources.contributor_id = :viewer".freeze

    # Asking for removal takes it out of the requester's sight for good, whatever the answer.
    NOT_ASKED_AWAY = <<~SQL.squish
      NOT EXISTS (SELECT 1 FROM removal_requests
                  WHERE removal_requests.memory_resource_id = memory_resources.id
                    AND removal_requests.requester_id = :viewer)
    SQL

    included do
      has_many :removal_requests, dependent: :delete_all
      has_many :flags, as: :flaggable, dependent: :delete_all

      scope :visible_to, ->(user) {
        next none if user.nil?

        where(memory_id: Memory.visible_to(user))
          .where(NOT_HIDDEN, viewer: user.id)
          .where(NOT_ASKED_AWAY, viewer: user.id)
      }
    end

    def hide! = update!(hidden_at: hidden_at || Time.current)

    # Back in sight, unless a removal request on it was answered "removed".
    def bring_back!
      update!(hidden_at: nil) unless removal_requests.outcome_removed.exists?
    end

    def hidden? = hidden_at.present?

    def removal_requested_for?(user)
      removal_requests.open.any? { |request| request.shown_to?(user) }
    end
  end
end
