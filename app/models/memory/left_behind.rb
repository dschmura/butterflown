class Memory
  # What happens to a person's memories in a community they've gone from. Both rules read the
  # membership as it stands, so coming back inside the window reconnects everything. See /docs/developer/leaving.
  module LeftBehind
    extend ActiveSupport::Concern

    HELD_FOR = 90.days

    AUTHOR_GONE = <<~SQL.squish
      EXISTS (SELECT 1 FROM memberships
              WHERE memberships.workspace_id = memories.workspace_id
                AND memberships.user_id = memories.author_id
                AND memberships.departure IN (:departures)
    SQL
    AUTHOR_GONE_WITHIN_THE_HOLD = "#{AUTHOR_GONE} AND memberships.discarded_at > :cutoff)".freeze
    AUTHOR_GONE_PAST_THE_HOLD = "#{AUTHOR_GONE} AND memberships.discarded_at <= :cutoff)".freeze

    included do
      # A removed member's own memories, to download for 90 days; deleting them is MemoryPolicy's call.
      scope :on_exit_page_of, ->(user, now: Time.current) {
        kept
          .where(author: user)
          .where(Visibility::OPEN_COMMUNITY)
          .where(AUTHOR_GONE_WITHIN_THE_HOLD, departures: %w[removed removed_for_cause], cutoff: now - HELD_FOR)
      }

      # Shared memories stay with the community; private ones go once the hold is up.
      scope :left_behind, ->(now:) {
        where(visibility: "only_me").where(AUTHOR_GONE_PAST_THE_HOLD, departures: %w[left removed removed_for_cause], cutoff: now - HELD_FOR)
      }
    end

    class_methods do
      # Re-asked per memory inside its transaction: someone invited back mid-purge keeps the rest.
      def purge_left_behind(now: Time.current)
        left_behind(now: now).find_each do |memory|
          transaction { memory.destroy! if left_behind(now: now).exists?(memory.id) }
        end
      end
    end
  end
end
