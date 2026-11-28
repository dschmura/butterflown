require "rails_helper"

RSpec.describe Moderation::History do
  let(:community) { create(:workspace, max_members: 30, anonymous_posting: true) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:person) { create(:membership, workspace: community).user }
  let(:member) { create(:membership, workspace: community).user }

  def history = described_class.new(community.memberships.find_by!(user: person))

  def memory_of(author, anonymous: false)
    create(:memory, workspace: community, author: author, visibility: "community", anonymous: anonymous)
  end

  it "holds the flags against what they posted, whole memories or single resources" do
    on_memory = Flag.create!(flaggable: memory_of(person), flagger: member, reason: "x")
    on_resource = Flag.create!(flaggable: memory_of(person).resources.first, flagger: member, reason: "x")
    Flag.create!(flaggable: memory_of(member), flagger: person, reason: "x")

    expect(history.flags_against).to contain_exactly(on_memory, on_resource)
  end

  it "holds the removal requests upheld against their resources, removed or changed" do
    resource = memory_of(person).resources.first
    removed = RemovalRequest.create!(memory_resource: resource, requester: member, recipients: "admins", reason: "x")
      .tap { |r| r.decide!("removed", by: admin) }
    other = memory_of(person).resources.first
    changed = RemovalRequest.create!(memory_resource: other, requester: member, recipients: "admins", reason: "x")
      .tap { |r| r.decide!("changed", by: admin) }
    third = memory_of(person).resources.first
    RemovalRequest.create!(memory_resource: third, requester: member, recipients: "admins", reason: "x")
      .tap { |r| r.decide!("kept", by: admin) }
    RemovalRequest.create!(memory_resource: memory_of(person).resources.first, requester: member, recipients: "admins", reason: "x")

    expect(history.upheld_requests).to contain_exactly(removed, changed)
  end

  it "never counts what they posted anonymously, which would say who wrote it" do
    anonymous = memory_of(person, anonymous: true)
    Flag.create!(flaggable: anonymous, flagger: member, reason: "x")
    RemovalRequest.create!(memory_resource: anonymous.resources.first, requester: member, recipients: "admins", reason: "x")
      .tap { |r| r.decide!("removed", by: admin) }

    expect(history).to have_attributes(flags_against: [], upheld_requests: [])
  end

  it "holds the block reports about them, and the block count once it reaches three" do
    blockers = Array.new(3) { create(:membership, workspace: community).user }
    blocks = blockers.map { |blocker| Block.create!(workspace: community, blocker: blocker, blocked: person) }
    report = blocks.first.report!(reason: "harassment")

    expect(history.block_reports).to contain_exactly(report)
    expect(history.blocked_by_count).to eq(3)
  end

  it "gives no block count under three" do
    Block.create!(workspace: community, blocker: member, blocked: person)

    expect(history.blocked_by_count).to be_nil
  end

  it "leaves out what happened in another community" do
    elsewhere = create(:workspace)
    [ person, member ].each { |user| create(:membership, workspace: elsewhere, user: user) }
    Flag.create!(flaggable: create(:memory, workspace: elsewhere, author: person, visibility: "community"), flagger: member, reason: "x")
    Block.create!(workspace: elsewhere, blocker: member, blocked: person).report!(reason: "other")

    expect(history).to have_attributes(flags_against: [], block_reports: [])
  end
end
