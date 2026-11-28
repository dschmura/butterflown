module Moderation
  # What one admin has to handle in one community: only items routed to them.
  # See /docs/developer/moderation.
  class Queue
    # A count, never the names of who blocked.
    Signal = Data.define(:person, :count)

    SIGNAL_AT = 3

    def initialize(workspace, admin)
      @workspace = workspace
      @admin = admin
    end

    # A request sent only to the author has no admin handlers, so it never appears.
    def removal_requests = handled(RemovalRequest.where(workspace: @workspace).open)

    def flags = handled(Flag.where(workspace: @workspace).open)

    def block_reports = handled(BlockReport.where(workspace: @workspace).open)

    # Members blocked by three or more current members, here or everywhere. Never about the admin reading it.
    def block_signals
      members = @workspace.memberships.kept.select(:user_id)
      Block.where(blocked_id: members, blocker_id: members)
        .merge(Block.where(workspace: @workspace).or(Block.where(everywhere: true)))
        .group(:blocked_id).distinct.count(:blocker_id)
        .select { |_person_id, count| count >= SIGNAL_AT }
        .filter_map do |person_id, count|
          person = User.find(person_id)
          Signal.new(person: person, count: count) if Moderation.admins_for(@workspace, involving: [ person ]).include?(@admin)
        end
    end

    private

    def handled(items) = items.select { |item| item.handled_by?(@admin) }
  end
end
