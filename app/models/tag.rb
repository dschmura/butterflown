# A person or typed name on one resource; it only decides whether a name shows. Never Trackable: the
# feed would announce tags on private memories. See /docs/developer/tags.
class Tag < ApplicationRecord
  STATES = %w[pending approved unnamed].freeze
  ANSWER_WITHIN = 14.days

  belongs_to :memory_resource
  belongs_to :tagged_user, class_name: "User", optional: true
  belongs_to :tagger, class_name: "User"

  has_one :memory, through: :memory_resource

  encrypts :typed_name

  enum :state, STATES.index_by(&:itself), validate: true

  validates :tagged_user_id, uniqueness: { scope: :memory_resource_id }, allow_nil: true
  validate :person_or_name
  validate :memory_not_anonymous
  validate :tagged_user_is_a_member
  validate :no_block_between_them, on: :create

  scope :visible_to, ->(user) { joins(:memory_resource).where(memory_resources: { memory_id: Memory.visible_to(user) }) }

  def self.lapse_overdue(now: Time.current)
    pending.where(expires_at: ..now).update_all(state: "unnamed", state_changed_at: now, updated_at: now)
  end

  def approve! = move_to("approved")
  def unname! = move_to("unnamed")
  def restore! = move_to("approved")

  def name_shown?
    approved? && !blocked_between_them?
  end

  private

  def move_to(state)
    update!(state: state, state_changed_at: Time.current, expires_at: nil)
  end

  def person_or_name
    errors.add(:base, :person_or_name) unless tagged_user.present? ^ typed_name.present?
  end

  def memory_not_anonymous
    errors.add(:base, :anonymous_memory) if memory_resource&.memory&.anonymous?
  end

  def tagged_user_is_a_member
    return if tagged_user.nil? || memory_resource.nil?
    errors.add(:tagged_user, :not_taggable) unless community.memberships.kept.exists?(user: tagged_user)
  end

  # The same answer as for a non-member, so a failed tag can't tell the tagger they were blocked.
  def no_block_between_them
    errors.add(:tagged_user, :not_taggable) if blocked_between_them?
  end

  def blocked_between_them?
    return false if tagged_user_id.nil? || tagger_id.nil?

    Block.where(blocker_id: [ tagger_id, tagged_user_id ], blocked_id: [ tagger_id, tagged_user_id ])
      .where("blocks.workspace_id = ? OR blocks.everywhere", community.id).exists?
  end

  def community
    memory_resource.memory.workspace
  end
end
