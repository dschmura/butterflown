class Membership
  # What a member may do in the community. Presets govern members only: admins and the owner act as
  # contributors, and a guest may do none of it. See /docs/developer/member-presets.
  module Preset
    extend ActiveSupport::Concern

    PRESETS = %w[contributor participant reader].freeze
    GUEST_ROLE_SLUG = "viewer"

    CAPABILITIES = {
      "contributor" => %i[post_memories reflect comment tag create_collections suggest_invites],
      "participant" => %i[reflect comment tag suggest_invites],
      "reader" => []
    }.freeze

    included do
      # nil until chosen, so an explicit "contributor" isn't mistaken for the column default.
      attribute :preset, :string, default: nil
      enum :preset, PRESETS.index_by(&:itself), instance_methods: false, validate: true

      before_validation :adopt_community_default_preset, on: :create
      # save!(validate: false) skips the line above; the template's concurrency specs take that path.
      before_create :adopt_community_default_preset
    end

    def guest?
      role&.slug == GUEST_ROLE_SLUG
    end

    # The owner holds manage_members too, so this answers "admin or owner".
    def admin?
      role&.permissions&.dig("manage_members") == true
    end

    def governed_by_preset?
      !guest? && !admin?
    end

    CAPABILITIES.values.flatten.uniq.each do |capability|
      define_method(:"may_#{capability}?") { may?(capability) }
    end

    private

    def may?(capability)
      return false if discarded? || guest?
      return true if admin?

      CAPABILITIES.fetch(preset).include?(capability)
    end

    def adopt_community_default_preset
      self.preset ||= workspace&.default_member_preset
    end
  end
end
