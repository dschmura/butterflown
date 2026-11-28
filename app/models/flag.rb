# A member asking the admins to look at a memory or one of its resources. Unlike a removal request,
# the flagger keeps seeing it. See /docs/developer/moderation.
class Flag < ApplicationRecord
  include Tenanted
  include Trackable
  include Moderation::Handled

  OUTCOMES = %w[acted dismissed].freeze

  belongs_to :flaggable, polymorphic: true
  belongs_to :flagger, class_name: "User"

  encrypts :reason

  enum :outcome, OUTCOMES.index_by(&:itself), prefix: true, validate: { allow_nil: true }

  before_validation :take_from_the_flagged, on: :create

  validates :reason, presence: true
  validates :flagger_id, uniqueness: { scope: [ :flaggable_type, :flaggable_id ] }
  validate :flagger_sees_it, :not_their_own, on: :create

  def involved = [ flagger, flagged_author ]

  def flagged_memory = flaggable.is_a?(Memory) ? flaggable : flaggable.memory

  def flagged_author = flaggable.is_a?(Memory) ? flaggable.author : flaggable.contributor

  def hide_now!(by:)
    flagged_resources.each(&:hide!)
    create_activity("flag.hidden", { "hidden_by" => by.id })
  end

  # Dismissing brings back what an urgent hide took away.
  def resolve!(outcome, by:)
    close!(by: by, outcome: outcome) do
      flagged_resources.each(&:bring_back!) if outcome_dismissed?
    end
  end

  private

  def flagged_resources = flaggable.is_a?(Memory) ? flaggable.resources.to_a : [ flaggable ]

  def take_from_the_flagged
    self.workspace ||= flagged_memory.workspace if flaggable
  end

  def flagger_sees_it
    return if flagger.nil? || flaggable.nil?

    errors.add(:flaggable, :not_visible) unless flaggable.class.visible_to(flagger).exists?(flaggable.id)
  end

  def not_their_own
    errors.add(:flaggable, :your_own) if flaggable && flagger_id == flagged_author&.id
  end
end
