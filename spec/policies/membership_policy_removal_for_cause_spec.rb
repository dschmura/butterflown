require "rails_helper"

RSpec.describe MembershipPolicy, "#remove_for_cause?", community_members: true do
  let(:community) { create(:workspace, max_members: 10).tap { |w| Current.workspace = w } }

  after { Current.workspace = nil }

  def permitted?(actor, target)
    described_class.new(actor, target).remove_for_cause?
  end

  it "lets an admin or the owner remove a member for cause" do
    [ community_member(:admin), community_member(:owner) ].each do |actor|
      expect(permitted?(actor, create(:membership, workspace: community))).to be true
    end
  end

  it "refuses an admin removing the owner, a role they couldn't grant" do
    owner = community_member(:owner)

    expect(permitted?(community_member(:admin), community.memberships.find_by(user: owner))).to be false
  end

  it "refuses a member" do
    expect(permitted?(community_member, create(:membership, workspace: community))).to be false
  end

  it "refuses removing yourself for cause; you leave instead" do
    admin = community_member(:admin)

    expect(permitted?(admin, community.memberships.find_by(user: admin))).to be false
  end

  it "refuses someone already gone" do
    gone = create(:membership, workspace: community).tap(&:leave!)

    expect(permitted?(community_member(:admin), gone)).to be false
  end

  it "refuses an admin from another community" do
    target = create(:membership, workspace: community)
    outsider = create(:membership, :admin, workspace: create(:workspace)).user

    expect(permitted?(outsider, target)).to be false
  end
end
