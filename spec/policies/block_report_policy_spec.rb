require "rails_helper"

RSpec.describe BlockReportPolicy do
  let(:community) { create(:workspace, max_members: 20).tap { |w| Current.workspace = w } }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:blocker) { create(:membership, workspace: community).user }
  let(:blocked) { create(:membership, workspace: community).user }
  let(:block) { Block.create!(workspace: community, blocker: blocker, blocked: blocked) }

  after { Current.workspace = nil }

  it "lets only the blocker report their block" do
    expect(described_class.new(blocker, block).report?).to be(true)
    expect(described_class.new(blocked, block).report?).to be(false)
  end

  it "lets only a handling admin resolve a report" do
    report = block.report!(reason: "other")

    expect([ admin, blocker ].map { |user| described_class.new(user, report).resolve? }).to eq([ true, false ])
  end
end
