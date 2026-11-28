# A member asking for a resource to be removed or changed. The requester stops seeing it at once;
# the author or the admins answer. See /docs/developer/moderation.
class RemovalRequest < ApplicationRecord
  include Tenanted
  include Trackable

  RECIPIENTS = %w[author admins both].freeze
  OUTCOMES = %w[removed changed kept].freeze
  ANSWER_WITHIN = 3.days

  class AlreadyDecided < StandardError; end

  belongs_to :memory_resource
  belongs_to :requester, class_name: "User"
  belongs_to :decided_by, class_name: "User", optional: true

  encrypts :reason

  enum :recipients, RECIPIENTS.index_by(&:itself), prefix: :to, validate: true
  enum :outcome, OUTCOMES.index_by(&:itself), prefix: true, validate: { allow_nil: true }

  before_validation :take_from_the_resource, :send_anonymous_through_admins, :start_the_clock, on: :create

  validates :reason, presence: true
  validate :requester_sees_it, :not_their_own, on: :create

  scope :open, -> { where(decided_at: nil) }
  scope :overdue, ->(now: Time.current) { open.where(due_at: ..now) }
  scope :made_by, ->(user) { where(requester: user) }

  def open? = decided_at.nil?

  def answered_by_admins? = to_admins? || to_both?

  # A request about an anonymous memory reaches its author only through an admin.
  def reaches_author? = to_author? || to_both? || relayed_at.present?

  def anonymous_author? = memory_resource.credit.anonymous?

  def handlers
    answered_by_admins? ? Moderation.admins_for(workspace, involving: [ requester, memory_resource.contributor ]) : []
  end

  def handled_by?(user) = user.present? && handlers.include?(user)

  # Who sees "removal requested" on the resource while it is open.
  def shown_to?(user)
    (user&.id == memory_resource.contributor_id && reaches_author?) || handled_by?(user)
  end

  def decide!(outcome, by:)
    transaction do
      lock!
      raise AlreadyDecided unless open?

      update!(outcome: outcome, decided_by: by, decided_at: Time.current)
      outcome_removed? ? memory_resource.hide! : memory_resource.bring_back!
      create_activity("removal_request.decided", { "outcome" => outcome, "decided_by" => by.id })
    end
  end

  def hide_now!(by:)
    memory_resource.hide!
    create_activity("removal_request.hidden", { "hidden_by" => by.id })
  end

  def relay!(by:)
    update!(relayed_at: Time.current)
    create_activity("removal_request.relayed", { "relayed_by" => by.id })
  end

  private

  # Decisions, urgent hides and relays are logged; the request itself is the record of asking.
  def track_creation = nil
  def track_update = nil

  def activity_visibility(_action) = "admin"

  def activity_workspace = workspace

  def take_from_the_resource
    self.workspace ||= memory_resource&.memory&.workspace
  end

  def send_anonymous_through_admins
    self.recipients = "admins" if memory_resource && anonymous_author?
  end

  def start_the_clock
    self.due_at ||= ANSWER_WITHIN.from_now
  end

  def requester_sees_it
    return if requester.nil? || memory_resource.nil?

    errors.add(:memory_resource, :not_visible) unless MemoryResource.visible_to(requester).exists?(memory_resource.id)
  end

  def not_their_own
    errors.add(:memory_resource, :your_own) if requester_id.present? && requester_id == memory_resource&.contributor_id
  end
end
