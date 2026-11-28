# A blocker choosing to tell the admins about a block, with a reason. Without one, admins never learn
# who blocked whom. It outlives the block: the admins were told. See /docs/developer/moderation.
class BlockReport < ApplicationRecord
  include Tenanted
  include Trackable
  include Moderation::Handled

  REASONS = %w[harassment unwanted_contact something_they_posted other].freeze

  belongs_to :reporter, class_name: "User"
  belongs_to :reported, class_name: "User"

  encrypts :note

  enum :reason, REASONS.index_by(&:itself), validate: true

  def involved = [ reporter, reported ]

  def resolve!(by:) = close!(by: by)
end
