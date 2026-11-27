# frozen_string_literal: true

# `community_member(:admin, preset: "reader")` adds a member to the example's `community` and returns the user.
module CommunityMemberHelpers
  def community_member(*traits, **attrs)
    create(:membership, *traits, workspace: community, **attrs).user
  end
end

RSpec.configure do |config|
  config.include CommunityMemberHelpers, community_members: true
end
