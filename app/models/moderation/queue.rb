module Moderation
  # What one admin has to handle in one community: only items routed to them.
  # See /docs/developer/moderation.
  class Queue
    # A count, never the names of who blocked.
    Signal = Data.define(:person, :count)

    def initialize(workspace, admin)
      @workspace = workspace
      @admin = admin
    end

    # A request sent only to the author has no admin handlers, so it never appears.
    def removal_requests = handled(RemovalRequest.where(workspace: @workspace).open)

    def flags = handled(Flag.where(workspace: @workspace).open)

    def block_reports = handled(BlockReport.where(workspace: @workspace).open)

    # Routed like any item about that person, so never shown to the admin it is about.
    def block_signals
      Moderation.blocked_by_counts(@workspace).filter_map do |person_id, count|
        person = User.find(person_id)
        Signal.new(person: person, count: count) if Moderation.admins_for(@workspace, involving: [ person ]).include?(@admin)
      end
    end

    private

    def handled(items) = items.select { |item| item.handled_by?(@admin) }
  end
end
