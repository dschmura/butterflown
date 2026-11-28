class Memory
  # What admins can do to a memory beyond what its audience allows. See /docs/developer/moderation.
  module Moderated
    extend ActiveSupport::Concern

    included do
      has_many :flags, as: :flaggable, dependent: :delete_all
      has_many :author_reveals, dependent: :delete_all
    end

    # Returns the author; MemoryPolicy#reveal_author? decides who may ask.
    def reveal_author_to!(admin, reason:)
      author_reveals.create!(workspace: workspace, revealed_by: admin, reason: reason)
      author
    end
  end
end
