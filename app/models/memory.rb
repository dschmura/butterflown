# One thing a member remembers, made of one or more resources. Private to its author until shared.
# Never Trackable: the community's activity feed would announce memories their authors kept private.
class Memory < ApplicationRecord
  include Tenanted
  include Discardable
  include Visibility

  AUDIENCES = %w[only_me specific_people community].freeze
  RULES = %w[viewers author].freeze

  belongs_to :author, class_name: "User"
  has_many :resources, -> { order(:id) }, class_name: "MemoryResource", inverse_of: :memory, dependent: :destroy

  enum :visibility, AUDIENCES.index_by(&:itself), instance_methods: false, scopes: false, validate: true
  enum :comment_rule, RULES.index_by(&:itself), instance_methods: false, scopes: false, validate: true
  enum :reflect_rule, RULES.index_by(&:itself), instance_methods: false, scopes: false, validate: true
  enum :tag_rule, RULES.index_by(&:itself), instance_methods: false, scopes: false, validate: true

  validate :author_is_a_member, on: :create
  validate :community_accepts_new_memories, on: :create
  validate :anonymity_allowed_by_community
  validate :has_a_resource, on: :create
  validate :anonymous_only_without_tags, on: :update

  private

  def author_is_a_member
    return if workspace.nil? || author.nil?
    errors.add(:author, :not_a_member) unless workspace.memberships.kept.exists?(user: author)
  end

  def community_accepts_new_memories
    return if workspace.nil?
    errors.add(:base, :community_read_only) unless workspace.accepts_new_memories?
  end

  def anonymity_allowed_by_community
    return unless anonymous? && workspace
    errors.add(:anonymous, :not_allowed_here) unless workspace.anonymous_posting?
  end

  def anonymous_only_without_tags
    return unless anonymous? && will_save_change_to_anonymous?
    errors.add(:anonymous, :has_tags) if Tag.joins(:memory_resource).exists?(memory_resources: { memory_id: id })
  end

  def has_a_resource
    errors.add(:base, :needs_a_resource) if resources.empty?
  end
end
