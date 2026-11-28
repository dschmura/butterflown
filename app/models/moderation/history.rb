module Moderation
  # One member's moderation record in one community, for its admins. Leaves out what they posted
  # anonymously, which would say who wrote it. See /docs/developer/moderation.
  class History
    UPHELD = %w[removed changed].freeze

    def initialize(membership)
      @workspace = membership.workspace
      @person = membership.user
    end

    def flags_against
      on_memories = Flag.where(flaggable_type: "Memory", flaggable_id: named_memories)
      on_resources = Flag.where(flaggable_type: "MemoryResource", flaggable_id: named_resources)
      on_memories.or(on_resources).to_a
    end

    def upheld_requests
      RemovalRequest.where(workspace: @workspace, memory_resource_id: named_resources, outcome: UPHELD).to_a
    end

    def block_reports = BlockReport.where(workspace: @workspace, reported: @person).to_a

    def blocked_by_count
      Moderation.blocked_by_counts(@workspace)[@person.id]
    end

    private

    def named_memories = Memory.where(workspace: @workspace, author: @person, anonymous: false).select(:id)

    # Their own resources on anonymous memories are anonymous; their perspectives on others' are not.
    def named_resources
      MemoryResource.joins(:memory).where(contributor: @person, memories: { workspace_id: @workspace.id })
        .where("memories.anonymous = FALSE OR memories.author_id <> memory_resources.contributor_id").select(:id)
    end
  end
end
