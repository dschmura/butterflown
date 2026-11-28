require "rails_helper"

RSpec.describe Moderation do
  let(:community) { create(:workspace, max_members: 20) }
  let(:member) { create(:membership, workspace: community).user }
  let(:other_member) { create(:membership, workspace: community).user }

  def admin_named(first_name)
    create(:membership, :admin, workspace: community, user: create(:user, first_name: first_name)).user
  end

  def handlers(*involving)
    described_class.admins_for(community, involving: involving)
  end

  it "hands an item to every admin, owner included" do
    rowan = admin_named("Rowan")
    owner = create(:membership, :owner, workspace: community).user

    expect(handlers(member, other_member)).to contain_exactly(rowan, owner)
  end

  it "routes around an admin with a block either way with anyone involved" do
    rowan = admin_named("Rowan")
    sage = admin_named("Sage")
    teal = admin_named("Teal")
    Block.create!(workspace: community, blocker: member, blocked: rowan)
    Block.create!(workspace: community, blocker: sage, blocked: other_member)

    expect(handlers(member, other_member)).to contain_exactly(teal)
  end

  it "counts a block made in every community they share" do
    rowan = admin_named("Rowan")
    sage = admin_named("Sage")
    elsewhere = create(:workspace)
    [ member, rowan ].each { |user| create(:membership, workspace: elsewhere, user: user) }
    Block.create!(workspace: elsewhere, blocker: member, blocked: rowan, everywhere: true)

    expect(handlers(member)).to contain_exactly(sage)
  end

  it "ignores a block made in another community only" do
    rowan = admin_named("Rowan")
    elsewhere = create(:workspace)
    [ member, rowan ].each { |user| create(:membership, workspace: elsewhere, user: user) }
    Block.create!(workspace: elsewhere, blocker: member, blocked: rowan)

    expect(handlers(member)).to contain_exactly(rowan)
  end

  it "falls back to the blocked admins when no other admin is clear" do
    rowan = admin_named("Rowan")
    Block.create!(workspace: community, blocker: member, blocked: rowan)

    expect(handlers(member)).to contain_exactly(rowan)
  end

  it "never hands an admin an item they are part of" do
    rowan = admin_named("Rowan")
    sage = admin_named("Sage")

    expect(handlers(member, rowan)).to contain_exactly(sage)
  end

  it "has nobody when the only admin is part of it" do
    rowan = admin_named("Rowan")

    expect(handlers(member, rowan)).to be_empty
  end

  it "leaves out admins who have left" do
    rowan = admin_named("Rowan")
    community.memberships.find_by(user: rowan).leave!

    expect(handlers(member)).to be_empty
  end
end
