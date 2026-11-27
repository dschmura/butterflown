class Memory < ApplicationRecord
  # Who may see a memory. Every read goes through visible_to; a code-smell spec holds that line.
  # See /docs/developer/memory-visibility.
  module Visibility
    extend ActiveSupport::Concern

    OPEN_COMMUNITY = <<~SQL.squish
      EXISTS (SELECT 1 FROM workspaces
              WHERE workspaces.id = memories.workspace_id
                AND workspaces.discarded_at IS NULL
                AND workspaces.suspended_at IS NULL)
    SQL

    VIEWER_IS_A_MEMBER = <<~SQL.squish
      EXISTS (SELECT 1 FROM memberships
              WHERE memberships.workspace_id = memories.workspace_id
                AND memberships.user_id = :viewer
                AND memberships.discarded_at IS NULL)
    SQL

    AUTHORED = "memories.author_id = :viewer".freeze

    NAMED = <<~SQL.squish
      memories.visibility <> 'only_me'
      AND EXISTS (SELECT 1 FROM memory_accesses
                  WHERE memory_accesses.memory_id = memories.id
                    AND memory_accesses.user_id = :viewer)
    SQL

    REACHED_THROUGH_COMMUNITY = <<~SQL.squish
      memories.visibility = 'community'
      AND (memories.visible_to_guests
           OR EXISTS (SELECT 1 FROM memberships
                      JOIN roles ON roles.id = memberships.role_id
                      WHERE memberships.workspace_id = memories.workspace_id
                        AND memberships.user_id = :viewer
                        AND memberships.discarded_at IS NULL
                        AND roles.slug <> :guest))
    SQL

    # A block in the memory's community, or an everywhere block from anywhere, beats every grant.
    NOT_BLOCKED_BY_AUTHOR = <<~SQL.squish
      NOT EXISTS (SELECT 1 FROM blocks
                  WHERE blocks.blocker_id = memories.author_id
                    AND blocks.blocked_id = :viewer
                    AND (blocks.workspace_id = memories.workspace_id OR blocks.everywhere))
    SQL

    # Anonymous memories stay, or blocking someone and watching what vanishes would unmask them.
    AUTHOR_NOT_BLOCKED_BY_VIEWER = <<~SQL.squish
      memories.anonymous
      OR NOT EXISTS (SELECT 1 FROM blocks
                  WHERE blocks.blocker_id = :viewer
                    AND blocks.blocked_id = memories.author_id
                    AND (blocks.workspace_id = memories.workspace_id OR blocks.everywhere))
    SQL

    # Any one grant is enough.
    GRANTS = [ AUTHORED, NAMED, REACHED_THROUGH_COMMUNITY ].map { |grant| "(#{grant})" }.join(" OR ").freeze

    included do
      has_many :accesses, class_name: "MemoryAccess", dependent: :delete_all

      scope :visible_to, ->(user) {
        next none if user.nil?

        kept
          .where(OPEN_COMMUNITY)
          .where(VIEWER_IS_A_MEMBER, viewer: user.id)
          .where(NOT_BLOCKED_BY_AUTHOR, viewer: user.id)
          .where(GRANTS, viewer: user.id, guest: Membership::Preset::GUEST_ROLE_SLUG)
      }

      # For the blocker's feed only; elsewhere the blocked person's content is collapsed, not hidden.
      scope :hiding_authors_blocked_by, ->(user) {
        user ? where(AUTHOR_NOT_BLOCKED_BY_VIEWER, viewer: user.id) : all
      }
    end
  end
end
