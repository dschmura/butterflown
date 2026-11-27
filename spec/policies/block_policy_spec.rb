require "rails_helper"

RSpec.describe BlockPolicy, :community_members do
  let(:community) { create(:workspace, max_members: 20).tap { |w| Current.workspace = w } }

  after { Current.workspace = nil }

  it "lets any community_member, guest or admin block someone" do
    target = community_member

    [ community_member, community_member(:viewer), community_member(:admin), community_member(preset: "reader") ].each do |user|
      expect(described_class.new(user, Block.new(workspace: community, blocker: user, blocked: target)).create?).to be true
    end
  end

  it "refuses someone who isn't a current community_member" do
    target = community_member

    [ create(:user), community_member(:deactivated) ].each do |user|
      expect(described_class.new(user, Block.new(workspace: community, blocker: user, blocked: target)).create?).to be false
    end
  end

  it "refuses blocking on someone else's behalf" do
    user = community_member

    expect(described_class.new(user, Block.new(workspace: community, blocker: community_member, blocked: community_member)).create?).to be false
  end

  it "lets only the blocker see or lift the block, never an admin" do
    blocker = community_member
    block = Block.create!(workspace: community, blocker: blocker, blocked: community_member)

    expect(described_class.new(blocker, block)).to have_attributes(show?: true, update?: true, destroy?: true)
    [ community_member(:admin), community_member(:owner), block.blocked, nil ].each do |user|
      expect(described_class.new(user, block)).to have_attributes(show?: false, update?: false, destroy?: false)
    end
  end

  it "lets the blocker see, widen or lift their block after leaving the community it was made in" do
    blocker = community_member
    block = Block.create!(workspace: community, blocker: blocker, blocked: community_member)
    community.memberships.find_by!(user: blocker).update_columns(discarded_at: Time.current)

    expect(described_class.new(blocker, block)).to have_attributes(show?: true, update?: true, destroy?: true)
  end

  it "lists only the viewer's own blocks, and none without a viewer" do
    me = community_member
    mine = Block.create!(workspace: community, blocker: me, blocked: community_member)
    Block.create!(workspace: community, blocker: community_member, blocked: me)

    expect(described_class::Scope.new(me, Block.all).resolve).to contain_exactly(mine)
    expect(described_class::Scope.new(nil, Block.all).resolve).to be_empty
  end
end
