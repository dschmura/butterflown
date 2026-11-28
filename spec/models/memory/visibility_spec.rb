require "rails_helper"

# Every viewer is checked against the exact set of memories they may see, in one world with decoys,
# so a query that returns nothing or everything fails most rows. See /docs/developer/memory-visibility.
RSpec.describe Memory, ".visible_to", type: :model do
  let(:community) { create(:workspace, max_members: 50) }
  let(:elsewhere) { create(:workspace) }

  def join(workspace, *traits, **attrs)
    create(:membership, *traits, workspace: workspace, **attrs).user
  end

  def remember(author, visibility: "community", workspace: community, **attrs)
    create(:memory, workspace: workspace, author: author, visibility: visibility, **attrs)
  end

  def name(memory, *people)
    people.each { |person| MemoryAccess.create!(memory: memory, user: person) }
    memory
  end

  let!(:author) { join(community) }
  let!(:member) { join(community) }
  let!(:admin) { join(community, :admin) }
  let!(:owner) { join(community, :owner) }
  let!(:guest) { join(community, :viewer) }
  let!(:named_member) { join(community) }
  let!(:named_guest) { join(community, :viewer) }
  let!(:named_admin) { join(community, :admin) }
  let!(:leaver) { join(community) }
  let!(:blocked) { join(community) }
  let!(:tagged) { join(community) }
  let!(:tagged_guest) { join(community, :viewer) }
  let!(:stranger) { join(elsewhere) }

  let!(:only_me) { remember(author, visibility: "only_me") }
  let!(:specific) { name(remember(author, visibility: "specific_people"), named_member, named_guest, named_admin, leaver, blocked) }
  let!(:shared) { name(remember(author), named_guest) }
  let!(:open_to_guests) { remember(author, visible_to_guests: true) }
  let!(:withdrawn) { name(remember(author, visibility: "only_me"), named_member) }
  let!(:deleted) { remember(author).tap { |memory| memory.update_columns(discarded_at: Time.current) } }
  let!(:left_behind) { remember(leaver) }
  let!(:decoy) { remember(stranger, workspace: elsewhere, visible_to_guests: true) }

  def tag(memory, person)
    memory.resources.first.tag(person: person, by: author).tap { |t| raise t.errors.full_messages.to_sentence unless t.persisted? }
  end

  before do
    tag(specific, tagged)
    tag(withdrawn, tagged)
    tag(shared, tagged_guest)
    Block.create!(workspace: community, blocker: author, blocked: blocked)
    community.memberships.find_by!(user: leaver).update_columns(discarded_at: Time.current)
  end

  def seen_by(viewer)
    Memory.visible_to(viewer)
  end

  expected = {
    author: %i[only_me specific shared open_to_guests withdrawn left_behind],
    member: %i[shared open_to_guests left_behind],
    admin: %i[shared open_to_guests left_behind],
    owner: %i[shared open_to_guests left_behind],
    guest: %i[open_to_guests],
    named_member: %i[specific shared open_to_guests left_behind],
    named_guest: %i[specific shared open_to_guests],
    named_admin: %i[specific shared open_to_guests left_behind],
    leaver: %i[],
    blocked: %i[left_behind],
    tagged: %i[specific shared open_to_guests left_behind],
    tagged_guest: %i[shared open_to_guests],
    stranger: %i[decoy]
  }

  expected.each do |viewer, memories|
    it "shows the #{viewer.to_s.tr('_', ' ')} exactly what they may see" do
      expect(seen_by(public_send(viewer))).to match_array(memories.map { |memory| public_send(memory) })
    end
  end

  it "keeps a private memory from admins and the owner, who see the shared ones beside it" do
    [ admin, owner ].each do |viewer|
      expect(seen_by(viewer)).to include(shared)
      expect(seen_by(viewer)).not_to include(only_me, specific)
    end
  end

  it "shows nothing to someone not signed in" do
    expect(Memory.visible_to(nil)).to be_empty
  end

  it "keeps an archived community readable" do
    community.update_columns(archived_at: Time.current)

    expect(seen_by(member)).to match_array([ shared, open_to_guests, left_behind ])
  end

  it "shows nothing from a deleted community, even to the author" do
    community.update_columns(discarded_at: Time.current)

    expect(seen_by(author)).to be_empty
    expect(seen_by(stranger)).to eq([ decoy ])
  end

  it "shows nothing from a suspended community, even to the author" do
    community.update_columns(suspended_at: Time.current)

    expect(seen_by(author)).to be_empty
    expect(seen_by(stranger)).to eq([ decoy ])
  end

  it "chains from a community's memories without leaking another community's" do
    stranger_here = join(community)

    expect(community.memories.visible_to(stranger)).to be_empty
    expect(community.memories.visible_to(stranger_here)).to match_array([ shared, open_to_guests, left_behind ])
  end
end
