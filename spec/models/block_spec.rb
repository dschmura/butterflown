require "rails_helper"

RSpec.describe Block, type: :model do
  let(:community) { create(:workspace, max_members: 20) }
  let!(:blocker) { create(:membership, workspace: community).user }
  let!(:blocked) { create(:membership, workspace: community).user }

  it "lets one member block another" do
    expect(Block.new(workspace: community, blocker: blocker, blocked: blocked)).to be_valid
  end

  it "refuses blocking yourself, in the database too" do
    block = Block.new(workspace: community, blocker: blocker, blocked: blocker)

    expect(block.tap(&:validate).errors).to be_added(:blocked, :yourself)
    expect { block.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
  end

  it "refuses blocking someone who isn't in the community" do
    outsider = create(:user)

    expect(Block.new(workspace: community, blocker: blocker, blocked: outsider).tap(&:validate).errors)
      .to be_added(:blocked, :not_a_member)
  end

  it "blocks a person once per community, in the database too" do
    Block.create!(workspace: community, blocker: blocker, blocked: blocked)

    expect(Block.new(workspace: community, blocker: blocker, blocked: blocked)).not_to be_valid
    expect { Block.new(workspace: community, blocker: blocker, blocked: blocked).save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "leaves no trace in the community's activity feed" do
    expect { Block.create!(workspace: community, blocker: blocker, blocked: blocked) }.not_to change(ActivityLog, :count)
  end

  describe "reach" do
    let(:other) { create(:workspace, max_members: 20) }

    before do
      create(:membership, workspace: other, user: blocker)
      create(:membership, workspace: other, user: blocked)
    end

    def hidden_from_blocked_in(workspace)
      memory = create(:memory, workspace: workspace, author: blocker, visibility: "community")
      !Memory.visible_to(blocked).exists?(memory.id)
    end

    it "applies in its own community only" do
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)

      expect(hidden_from_blocked_in(community)).to be true
      expect(hidden_from_blocked_in(other)).to be false
    end

    it "applies in every community they share when the blocker asks for that" do
      Block.create!(workspace: community, blocker: blocker, blocked: blocked, everywhere: true)

      expect(hidden_from_blocked_in(community)).to be true
      expect(hidden_from_blocked_in(other)).to be true
    end

    it "covers a community either of them joins after an everywhere block" do
      Block.create!(workspace: community, blocker: blocker, blocked: blocked, everywhere: true)
      later = create(:workspace, max_members: 20)
      create(:membership, workspace: later, user: blocker)
      create(:membership, workspace: later, user: blocked)

      expect(hidden_from_blocked_in(later)).to be true
    end

    it "keeps hiding the blocker's memories even when the blocked person is named on one" do
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)
      memory = create(:memory, workspace: community, author: blocker, visibility: "specific_people")
      MemoryAccess.create!(memory: memory, user: blocked)

      expect(Memory.visible_to(blocked)).not_to include(memory)
    end

    it "hides the blocker's anonymous memories from the blocked person too, as the spec reads" do
      community.update!(anonymous_posting: true)
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)
      anonymous = create(:memory, workspace: community, author: blocker, visibility: "community", anonymous: true)

      expect(Memory.visible_to(blocked)).not_to include(anonymous)
    end

    it "stops applying once lifted" do
      block = Block.create!(workspace: community, blocker: blocker, blocked: blocked)
      block.destroy!

      expect(hidden_from_blocked_in(community)).to be false
    end

    it "hides nothing of the blocked person's from anyone else" do
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)
      bystander = create(:membership, workspace: community).user
      memory = create(:memory, workspace: community, author: blocked, visibility: "community")

      expect(Memory.visible_to(bystander)).to include(memory)
    end
  end

  describe "the blocker's feed" do
    let(:other_author) { create(:membership, workspace: community).user }

    def feed_of(user, workspace = community)
      workspace.memories.visible_to(user).hiding_authors_blocked_by(user)
    end

    def posted_by(author, workspace = community, **attrs)
      create(:memory, workspace: workspace, author: author, visibility: "community", **attrs)
    end

    it "hides the blocked person's memories and keeps everyone else's, the blocker's own included" do
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)
      theirs = posted_by(blocked)
      kept = [ posted_by(other_author), posted_by(other_author), posted_by(blocker) ]

      expect(feed_of(blocker)).to match_array(kept)
      expect(Memory.visible_to(blocker)).to include(theirs)
    end

    it "keeps the blocked person's anonymous memories, so a block can't reveal who wrote one" do
      community.update!(anonymous_posting: true)
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)
      anonymous = posted_by(blocked, anonymous: true)

      expect(feed_of(blocker)).to include(anonymous)
    end

    it "hides only where the block reaches" do
      other = create(:workspace, max_members: 20)
      [ blocker, blocked ].each { |user| create(:membership, workspace: other, user: user) }
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)
      elsewhere = posted_by(blocked, other)

      expect(feed_of(blocker, other)).to include(elsewhere)

      Block.find_by!(blocker: blocker).update!(everywhere: true)

      expect(feed_of(blocker, other)).not_to include(elsewhere)
    end

    it "hides nothing for someone not signed in" do
      memory = posted_by(blocked)

      expect(Memory.where(id: memory.id).hiding_authors_blocked_by(nil)).to eq([ memory ])
    end
  end
end
