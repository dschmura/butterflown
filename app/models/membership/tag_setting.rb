class Membership
  # How a member appears when tagged in this community: approve each tag first, or okay appearing.
  module TagSetting
    extend ActiveSupport::Concern

    included do
      enum :tag_setting, { approve: "approve", okay: "okay" }, prefix: true, validate: true
    end
  end
end
