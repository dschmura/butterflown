require "rails_helper"

RSpec.describe Moderation::Queue do
  let(:community) { create(:workspace, max_members: 30) }
  let(:rowan) { create(:membership, :admin, workspace: community).user }
  let(:sage) { create(:membership, :admin, workspace: community).user }
  let(:author) { create(:membership, workspace: community).user }
  let(:member) { create(:membership, workspace: community).user }
  let(:memory) { create(:memory, workspace: community, author: author, visibility: "community") }

  def queue_for(admin) = described_class.new(community, admin)

  def blockers_of(person, count)
    Array.new(count) { create(:membership, workspace: community).user }
      .each { |blocker| Block.create!(workspace: community, blocker: blocker, blocked: person) }
  end

  describe "the items" do
    it "holds the open removal requests that reach the admins, flags and block reports" do
      [ rowan, sage ]
      request = RemovalRequest.create!(memory_resource: memory.resources.first, requester: member, recipients: "admins", reason: "x")
      RemovalRequest.create!(memory_resource: memory.resources.first, requester: create(:membership, workspace: community).user, recipients: "author", reason: "x")
      flag = Flag.create!(flaggable: memory, flagger: member, reason: "x")
      report = Block.create!(workspace: community, blocker: member, blocked: author).report!(reason: "other")

      queue = queue_for(rowan)

      expect(queue).to have_attributes(removal_requests: [ request ], flags: [ flag ], block_reports: [ report ])
    end

    it "drops what has been answered" do
      [ rowan, sage ]
      Flag.create!(flaggable: memory, flagger: member, reason: "x").resolve!("dismissed", by: sage)

      expect(queue_for(rowan).flags).to be_empty
    end

    it "leaves out what another community holds" do
      [ rowan, sage ]
      elsewhere = create(:membership, :admin, workspace: create(:workspace)).user
      Flag.create!(flaggable: memory, flagger: member, reason: "x")

      expect(described_class.new(community, elsewhere).flags).to be_empty
    end

    it "sends an item past an admin with a block involved, to the others" do
      [ rowan, sage ]
      Block.create!(workspace: community, blocker: member, blocked: rowan)
      flag = Flag.create!(flaggable: memory, flagger: member, reason: "x")

      expect([ queue_for(rowan).flags, queue_for(sage).flags ]).to eq([ [], [ flag ] ])
    end
  end

  describe "the block signal" do
    it "shows a person blocked by three or more members, with the count and never the names" do
      [ rowan, sage ]
      blockers_of(author, 3)

      signal = queue_for(rowan).block_signals.sole
      expect(signal).to have_attributes(person: author, count: 3)
      expect(signal.to_h.keys).to contain_exactly(:person, :count)
    end

    it "stays quiet under three" do
      [ rowan, sage ]
      blockers_of(author, 2)

      expect(queue_for(rowan).block_signals).to be_empty
    end

    it "counts an everywhere block made in another community they share" do
      [ rowan, sage ]
      blockers_of(author, 2)
      elsewhere = create(:workspace)
      third = create(:membership, workspace: community).user
      [ third, author ].each { |user| create(:membership, workspace: elsewhere, user: user) }
      Block.create!(workspace: elsewhere, blocker: third, blocked: author, everywhere: true)

      expect(queue_for(rowan).block_signals.sole.count).to eq(3)
    end

    it "doesn't count blockers who have left" do
      [ rowan, sage ]
      blockers = blockers_of(author, 3)
      community.memberships.find_by(user: blockers.first).leave!

      expect(queue_for(rowan).block_signals).to be_empty
    end

    it "is never shown to the admin it is about, only to the others" do
      [ rowan, sage ]
      blockers_of(rowan, 3)

      expect(queue_for(rowan).block_signals).to be_empty
      expect(queue_for(sage).block_signals.sole.person).to eq(rowan)
    end

    it "isn't shown at all about the only admin" do
      blockers_of(rowan, 3)

      expect(queue_for(rowan).block_signals).to be_empty
    end
  end

  it "is empty for someone who isn't an admin here" do
    Flag.create!(flaggable: memory, flagger: member, reason: "x")
    rowan

    expect(queue_for(member)).to have_attributes(removal_requests: [], flags: [], block_reports: [], block_signals: [])
  end
end
