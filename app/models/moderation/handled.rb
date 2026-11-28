module Moderation
  # An item admins handle and close once. Includers include Trackable first, so these overrides sit
  # above it, and define #involved. See /docs/developer/moderation.
  module Handled
    extend ActiveSupport::Concern

    class AlreadyResolved < StandardError; end

    included do
      belongs_to :resolved_by, class_name: "User", optional: true

      scope :open, -> { where(resolved_at: nil) }
    end

    def open? = resolved_at.nil?

    def handlers = Moderation.admins_for(workspace, involving: involved)

    def handled_by?(user) = user.present? && handlers.include?(user)

    private

    def close!(by:, **attributes)
      transaction do
        lock!
        raise AlreadyResolved unless open?

        update!(resolved_by: by, resolved_at: Time.current, **attributes)
        yield if block_given?
        create_activity("#{model_name.param_key}.resolved", { "resolved_by" => by.id, **attributes.stringify_keys })
      end
    end

    # Only what admins do is logged; the item itself is the record of raising it.
    def track_creation = nil
    def track_update = nil

    def activity_visibility(_action) = "admin"

    def activity_workspace = workspace
  end
end
