require "rails_helper"

RSpec.describe FlagPolicy do
  let(:community) { create(:workspace, max_members: 20).tap { |w| Current.workspace = w } }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:author) { create(:membership, workspace: community).user }
  let(:flagger) { create(:membership, workspace: community).user }
  let(:memory) { create(:memory, workspace: community, author: author, visibility: "community") }

  after { Current.workspace = nil }

  def policy(user, record) = described_class.new(user, record)

  it "lets a member who sees it flag it, in their own name, in this community" do
    expect(policy(flagger, Flag.new(flaggable: memory, flagger: flagger, reason: "x")).create?).to be(true)
    expect(policy(flagger, Flag.new(flaggable: memory, flagger: author, reason: "x")).create?).to be(false)
    expect(policy(author, Flag.new(flaggable: memory, flagger: author, reason: "x")).create?).to be(false)
  end

  it "refuses an item from another community than the one at hand" do
    elsewhere = create(:workspace)
    create(:membership, workspace: elsewhere, user: flagger)
    theirs = create(:memory, workspace: elsewhere, visibility: "community")

    expect(policy(flagger, Flag.new(flaggable: theirs, flagger: flagger, reason: "x")).create?).to be(false)
  end

  it "lets only a handling admin hide or resolve an open flag" do
    record = Flag.create!(flaggable: memory, flagger: flagger, reason: "x")

    expect([ admin, author, flagger ].map { |user| policy(user, record).resolve? }).to eq([ true, false, false ])
    expect(policy(admin, record).hide_now?).to be(true)
    record.resolve!("dismissed", by: admin)
    expect(policy(admin, record).resolve?).to be(false)
  end
end
