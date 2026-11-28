class MemoryResource < ApplicationRecord
  # Tagging a person or a typed name on this resource. See /docs/developer/tags.
  module Tagging
    extend ActiveSupport::Concern

    included do
      has_many :tags, dependent: :delete_all
    end

    # Returns the tag, persisted or carrying its errors.
    def tag(by:, person: nil, name: nil)
      tags.create(tagger: by, tagged_user: person, typed_name: name, state_changed_at: Time.current, **opening_state(person, by))
    end

    private

    def opening_state(person, tagger)
      return { state: "approved" } if person.nil? || person == tagger || okay_appearing?(person)

      { state: "pending", expires_at: (memory.visibility == "only_me" ? nil : Tag::ANSWER_WITHIN.from_now) }
    end

    def okay_appearing?(person)
      memory.workspace.memberships.kept.find_by(user: person)&.tag_setting == "okay"
    end
  end
end
