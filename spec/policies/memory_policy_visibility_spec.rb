require "rails_helper"

RSpec.describe MemoryPolicy, "visibility" do
  let(:community) { create(:workspace, max_members: 50).tap { |w| Current.workspace = w } }

  after { Current.workspace = nil }

  def join(*traits)
    create(:membership, *traits, workspace: community).user
  end

  def agree_everywhere(viewers, memories)
    viewers.product(memories).each do |viewer, memory|
      shown = described_class.new(viewer, memory).show?
      listed = described_class::Scope.new(viewer, community.memories).resolve.include?(memory)

      expect(shown).to eq(listed), "viewer #{viewers.index(viewer)}, memory #{memories.index(memory)}"
    end
  end

  it "answers show? and the scope identically for every viewer and every memory" do
    author = join
    named = join
    named_guest = join(:viewer)
    leaver = join
    viewers = [ author, named, join(:admin), join(:owner), join(:viewer), named_guest, leaver, create(:user), nil ]
    memories = [
      create(:memory, workspace: community, author: author, visibility: "only_me"),
      create(:memory, workspace: community, author: author, visibility: "specific_people").tap { |m| [ named, named_guest, leaver ].each { |p| MemoryAccess.create!(memory: m, user: p) } },
      create(:memory, workspace: community, author: author, visibility: "community"),
      create(:memory, workspace: community, author: author, visibility: "community", visible_to_guests: true),
      create(:memory, workspace: community, author: author, visibility: "community").tap { |m| m.update_columns(discarded_at: Time.current) }
    ]
    community.memberships.find_by!(user: leaver).update_columns(discarded_at: Time.current)

    agree_everywhere(viewers, memories)
    expect(described_class.new(author, memories.first).show?).to be true
    expect(described_class.new(named_guest, memories.second).show?).to be true
    expect(described_class.new(nil, memories.third).show?).to be false
  end

  it "agrees that a suspended community shows nothing" do
    author = join
    memory = create(:memory, workspace: community, author: author, visibility: "community")
    community.update_columns(suspended_at: Time.current)

    agree_everywhere([ author ], [ memory ])
    expect(described_class.new(author, memory).show?).to be false
  end

  it "refuses show? for a memory from another community, even to its author" do
    other = create(:workspace)
    author = create(:membership, workspace: other).user
    memory = create(:memory, workspace: other, author: author, visibility: "community")

    expect(described_class.new(author, memory).show?).to be false
    expect(described_class::Scope.new(author, community.memories).resolve).to be_empty
  end
end
