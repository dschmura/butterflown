class Workspace < ApplicationRecord
  # The community's memories, and the one way a new one is posted.
  module Memories
    extend ActiveSupport::Concern

    included do
      has_many :memories, dependent: :destroy
    end

    def accepts_new_memories?
      !(archived? || discarded? || suspended?)
    end

    # Returns the memory, persisted or carrying its errors. Resources are hashes of
    # MemoryResource attributes; each is credited to the author.
    def post_memory(author:, resources:, **attrs)
      memory = memories.build(attrs.merge(author: author))
      resources.each { |resource| memory.resources.build(resource.merge(contributor: author)) }

      transaction do
        lock! # serializes with archive and suspend, so the read-only check sees committed state
        memory.save
      end
      memory
    end
  end
end
