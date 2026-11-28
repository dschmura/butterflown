require "rails_helper"

RSpec.describe Membership, type: :model do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:onlooker) { create(:membership, workspace: community).user }
  let(:membership) { create(:membership, workspace: community) }
  let(:person) { membership.user }

  def memory_of(author, **attributes)
    create(:memory, workspace: community, author: author, visibility: "community", **attributes)
  end

  describe "#clear_memories_for_cause!" do
    let!(:named) { memory_of(person) }
    let!(:anonymous) { memory_of(person, anonymous: true) }
    let!(:someone_elses) { memory_of(onlooker) }

    before { membership.remove_for_cause!(by: admin, reason: "Threats") }

    it "deletes every memory they posted here, anonymous ones too, without listing which" do
      membership.clear_memories_for_cause!(by: admin)

      expect(Memory.kept.where(id: [ named, anonymous ])).to be_empty
      expect(Memory.visible_to(onlooker)).to contain_exactly(someone_elses)
    end

    it "logs the clearing with a count, where only admins read it" do
      membership.clear_memories_for_cause!(by: admin)

      entry = ActivityLog.find_by!(action: "membership.memories_cleared")
      expect(entry).to have_attributes(visibility: "admin")
      expect(entry.metadata).to eq("count" => 2, "cleared_by" => admin.id)
    end

    it "leaves their memories in another community alone" do
      elsewhere = create(:workspace)
      create(:membership, workspace: elsewhere, user: person)
      theirs = create(:memory, workspace: elsewhere, author: person, visibility: "community")

      membership.clear_memories_for_cause!(by: admin)

      expect(theirs.reload.discarded_at).to be_nil
    end
  end

  it "refuses to clear the memories of someone not removed for cause" do
    membership.leave!

    expect { membership.clear_memories_for_cause!(by: admin) }.to raise_error(Membership::NotRemovedForCause)
  end
end
