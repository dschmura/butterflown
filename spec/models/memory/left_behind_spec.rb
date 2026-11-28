require "rails_helper"

RSpec.describe Memory, type: :model do
  let(:community) { create(:workspace, max_members: 20) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:author_membership) { create(:membership, workspace: community) }
  let(:author) { author_membership.user }

  def memory(visibility = "only_me", workspace: community)
    create(:memory, workspace: workspace, author: author, visibility: visibility)
  end

  describe ".purge_left_behind" do
    it "purges a private memory 90 days after its author left" do
      private_memory = memory
      author_membership.leave!

      Memory.purge_left_behind(now: 90.days.from_now + 1.minute)

      expect(Memory.exists?(private_memory.id)).to be(false)
    end

    it "does the same for someone an admin removed" do
      private_memory = memory
      author_membership.deactivate!(removed_by: admin)

      Memory.purge_left_behind(now: 90.days.from_now + 1.minute)

      expect(Memory.exists?(private_memory.id)).to be(false)
    end

    it "holds it until the 90 days are up" do
      private_memory = memory
      author_membership.leave!

      Memory.purge_left_behind(now: 90.days.from_now - 1.minute)

      expect(Memory.exists?(private_memory.id)).to be(true)
    end

    it "hands a removed member's memory from the exit page to the purge at exactly 90 days" do
      freeze_time do
        private_memory = memory
        author_membership.deactivate!(removed_by: admin)
        boundary = 90.days.from_now

        expect(Memory.on_exit_page_of(author, now: boundary - 1.second)).to include(private_memory)
        expect(Memory.on_exit_page_of(author, now: boundary)).to be_empty
        expect(Memory.left_behind(now: boundary - 1.second)).to be_empty
        expect(Memory.left_behind(now: boundary)).to include(private_memory)
      end
    end

    it "starts the 90 days again for someone who came back and then left again" do
      private_memory = memory
      author_membership.leave!
      travel(80.days) { author_membership.reactivate!(granted_by: admin) }
      travel(81.days) { author_membership.deactivate!(removed_by: admin) }

      Memory.purge_left_behind(now: 100.days.from_now)

      expect(Memory.exists?(private_memory.id)).to be(true)
      expect(author_membership.reload.departure).to eq("removed")
    end

    it "purges a private memory they had already deleted, too" do
      private_memory = memory.tap(&:discard!)
      author_membership.leave!

      Memory.purge_left_behind(now: 1.year.from_now)

      expect(Memory.exists?(private_memory.id)).to be(false)
    end

    it "spares the rest of a batch when the person is invited back mid-purge" do
      private_memories = [ memory, memory ]
      author_membership.leave!
      asked = 0
      allow(Memory).to receive(:left_behind).and_wrap_original do |original, **args|
        asked += 1
        author_membership.reactivate!(granted_by: admin) if asked == 2
        original.call(**args)
      end

      Memory.purge_left_behind(now: 1.year.from_now)

      expect(Memory.where(id: private_memories).count).to eq(2)
    end

    it "keeps it for someone who came back, however long they were away" do
      private_memory = memory
      author_membership.leave!
      author_membership.reactivate!(granted_by: admin)

      Memory.purge_left_behind(now: 1.year.from_now)

      expect(Memory.exists?(private_memory.id)).to be(true)
    end

    it "keeps shared memories in sight of the community, whether the author left or was removed" do
      reader = create(:membership, workspace: community).user
      shared = memory("community")
      other_membership = create(:membership, workspace: community)
      removed_ones = create(:memory, workspace: community, author: other_membership.user, visibility: "community")
      author_membership.leave!
      other_membership.deactivate!(removed_by: admin)

      expect(Memory.visible_to(reader)).to contain_exactly(shared, removed_ones)
    end

    it "keeps shared memories, which stay with the community" do
      shared = [ memory("community"), memory("specific_people") ]
      author_membership.leave!

      Memory.purge_left_behind(now: 1.year.from_now)

      expect(Memory.where(id: shared).count).to eq(2)
    end

    it "keeps private memories of people still here" do
      private_memory = memory

      Memory.purge_left_behind(now: 1.year.from_now)

      expect(Memory.exists?(private_memory.id)).to be(true)
    end

    it "keeps their private memories in a community they haven't left" do
      elsewhere = create(:workspace)
      create(:membership, workspace: elsewhere, user: author)
      kept_elsewhere = memory(workspace: elsewhere)
      memory
      author_membership.leave!

      Memory.purge_left_behind(now: 1.year.from_now)

      expect(Memory.where(author: author).pluck(:id)).to eq([ kept_elsewhere.id ])
    end

    it "takes the memory's resources and tags with it" do
      private_memory = memory
      private_memory.resources.first.tag(by: author, name: "A cousin")
      author_membership.leave!

      expect { Memory.purge_left_behind(now: 1.year.from_now) }
        .to change(MemoryResource, :count).by(-1).and change(Tag, :count).by(-1)
    end
  end

  describe ".on_exit_page_of" do
    it "holds a removed member's own memories, whatever their audience, for 90 days" do
      own = [ memory, memory("community") ]
      author_membership.deactivate!(removed_by: admin)

      expect(Memory.on_exit_page_of(author)).to match_array(own)
    end

    it "shows them nobody else's, not even another removed member's" do
      create(:memory, workspace: community, author: admin, visibility: "community")
      other = create(:membership, workspace: community)
      create(:memory, workspace: community, author: other.user, visibility: "community")
      [ author_membership, other ].each { |membership| membership.deactivate!(removed_by: admin) }

      expect(Memory.on_exit_page_of(author)).to be_empty
    end

    it "is gone after 90 days" do
      memory
      author_membership.deactivate!(removed_by: admin)

      expect(Memory.on_exit_page_of(author, now: 90.days.from_now + 1.minute)).to be_empty
    end

    it "holds the memories of someone who left on their own too, for 90 days" do
      own = memory
      author_membership.leave!

      expect(Memory.on_exit_page_of(author)).to contain_exactly(own)
      expect(Memory.on_exit_page_of(author, now: 90.days.from_now + 1.minute)).to be_empty
    end

    it "isn't there for someone still a member" do
      memory

      expect(Memory.on_exit_page_of(author)).to be_empty
    end

    it "leaves out memories they already deleted" do
      memory.discard!
      author_membership.deactivate!(removed_by: admin)

      expect(Memory.on_exit_page_of(author)).to be_empty
    end

    it "leaves out a community that has since been deleted" do
      memory
      author_membership.deactivate!(removed_by: admin)
      community.update_column(:discarded_at, Time.current)

      expect(Memory.on_exit_page_of(author)).to be_empty
    end
  end
end
