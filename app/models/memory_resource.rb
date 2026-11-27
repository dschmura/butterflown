# One piece of a memory: a written reflection or a photo. See /docs/developer/memories.
class MemoryResource < ApplicationRecord
  KINDS = %w[written_reflection photo].freeze

  belongs_to :memory, inverse_of: :resources
  belongs_to :contributor, class_name: "User"

  has_one_attached :photo

  encrypts :body

  enum :kind, KINDS.index_by(&:itself), prefix: true, validate: true

  validates :body, presence: true, if: :kind_written_reflection?
  validates :photo, content_type: ApplicationRecord::IMAGE_CONTENT_TYPES, size: { less_than: 20.megabytes }
  validates :content_warning, length: { maximum: 60 }
  validate :photo_attached_to_a_photo

  def perspective?
    contributor_id != memory.author_id
  end

  private

  def photo_attached_to_a_photo
    if kind_photo?
      errors.add(:photo, :blank) unless photo.attached?
    elsif photo.attached?
      errors.add(:photo, :only_on_a_photo)
    end
  end
end
