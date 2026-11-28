# An admin learning who wrote an anonymous memory, with a reason. Every reveal is logged where
# only admins read it. See /docs/developer/moderation.
class AuthorReveal < ApplicationRecord
  include Tenanted
  include Trackable

  belongs_to :memory
  belongs_to :revealed_by, class_name: "User"

  encrypts :reason

  validates :reason, presence: true
  validate :memory_is_anonymous, on: :create

  private

  def track_creation
    create_activity("author_reveal.created", { "revealed_by" => revealed_by_id, "memory_id" => memory_id })
  end

  def track_update = nil

  def activity_visibility(_action) = "admin"

  def activity_workspace = workspace

  def memory_is_anonymous
    errors.add(:memory, :not_anonymous) unless memory&.anonymous?
  end
end
