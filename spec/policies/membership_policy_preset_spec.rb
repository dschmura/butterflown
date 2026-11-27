require "rails_helper"

RSpec.describe MembershipPolicy, "#change_preset?" do
  let(:workspace) { create(:workspace).tap { |w| Current.workspace = w } }

  after { Current.workspace = nil }

  def user_in(*traits)
    create(:membership, *traits, workspace: workspace).user
  end

  def permitted?(actor, target)
    described_class.new(actor, target).change_preset?
  end

  it "lets an admin move a member to another preset" do
    expect(permitted?(user_in(:admin), create(:membership, workspace: workspace))).to be true
  end

  it "lets the owner move a member to another preset" do
    expect(permitted?(user_in(:owner), create(:membership, workspace: workspace))).to be true
  end

  it "refuses a member moving another member" do
    expect(permitted?(user_in, create(:membership, workspace: workspace))).to be false
  end

  it "refuses moving an admin, the owner or a guest, whom presets don't govern" do
    admin = user_in(:admin)

    [ :admin, :owner, :viewer ].each do |trait|
      expect(permitted?(admin, create(:membership, trait, workspace: workspace))).to be(false), trait.to_s
    end
  end

  it "refuses a member who has left" do
    expect(permitted?(user_in(:admin), create(:membership, :deactivated, workspace: workspace))).to be false
  end

  it "refuses an admin reaching a member of another community" do
    target = create(:membership, workspace: create(:workspace))

    expect(permitted?(user_in(:admin), target)).to be false
  end

  it "refuses a guest or a reader moving anyone" do
    target = create(:membership, workspace: workspace)
    reader = create(:membership, workspace: workspace, preset: "reader").user

    expect(permitted?(user_in(:viewer), target)).to be false
    expect(permitted?(reader, target)).to be false
  end
end
