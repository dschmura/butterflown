require "rails_helper"

RSpec.describe Flag, type: :model do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:author) { create(:membership, workspace: community).user }
  let(:flagger) { create(:membership, workspace: community).user }
  let(:onlooker) { create(:membership, workspace: community).user }
  let(:memory) { create(:memory, workspace: community, author: author, visibility: "community") }

  def flag(target = memory, by: flagger, reason: "This names a child without asking")
    Flag.create!(flaggable: target, flagger: by, reason: reason)
  end

  describe "flagging" do
    it "takes a memory or one of its resources" do
      expect([ flag, flag(memory.resources.first, by: onlooker) ].map(&:flaggable)).to eq([ memory, memory.resources.first ])
    end

    it "needs a reason" do
      expect { flag(reason: "") }.to raise_error(ActiveRecord::RecordInvalid, /reason/i)
    end

    it "is open to anyone who can see it, and no one else" do
      private_memory = create(:memory, workspace: community, author: author, visibility: "only_me")

      expect { flag(private_memory) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "isn't for your own memory" do
      expect { flag(by: author) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "is once per person per item" do
      flag

      expect { flag }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "leaves the item in the flagger's sight" do
      flag

      expect(Memory.visible_to(flagger)).to include(memory)
    end

    it "keeps its reason encrypted at rest" do
      record = flag

      raw = Flag.connection.select_value("SELECT reason FROM flags WHERE id = #{record.id}")
      expect(raw).not_to include("child")
    end
  end

  describe "who handles it" do
    it "routes around an admin with a block involving the author, even on an anonymous memory" do
      sage = create(:membership, :admin, workspace: community).user
      anonymous = create(:memory, workspace: community, author: author, visibility: "community", anonymous: true)
      Block.create!(workspace: community, blocker: author, blocked: admin)

      expect(flag(anonymous).handlers).to contain_exactly(sage)
    end
  end

  describe "#hide_now!" do
    it "hides every resource of a flagged memory from everyone but its author, and logs it" do
      flag.hide_now!(by: admin)

      expect(MemoryResource.visible_to(onlooker)).to be_empty
      expect(MemoryResource.visible_to(author)).to match_array(memory.resources)
      expect(ActivityLog.find_by!(action: "flag.hidden")).to have_attributes(visibility: "admin")
    end

    it "hides only the flagged resource" do
      second = create(:memory_resource, memory: memory, contributor: onlooker)

      flag(memory.resources.first).hide_now!(by: admin)

      expect(MemoryResource.visible_to(flagger)).to contain_exactly(second)
    end
  end

  describe "#resolve!" do
    it "closes it, with who and how, and logs it without the reason" do
      record = flag

      freeze_time do
        record.resolve!("acted", by: admin)

        expect(record.reload).to have_attributes(outcome: "acted", resolved_by: admin, resolved_at: Time.current, open?: false)
      end
      entry = ActivityLog.find_by!(action: "flag.resolved")
      expect(entry).to have_attributes(visibility: "admin")
      expect(entry.metadata.to_s).not_to include("child")
    end

    it "brings back what it hid when dismissed" do
      record = flag.tap { |f| f.hide_now!(by: admin) }

      record.resolve!("dismissed", by: admin)

      expect(MemoryResource.visible_to(onlooker)).to match_array(memory.resources)
    end

    it "keeps it hidden when acted on" do
      record = flag.tap { |f| f.hide_now!(by: admin) }

      record.resolve!("acted", by: admin)

      expect(MemoryResource.visible_to(onlooker)).to be_empty
    end

    it "doesn't bring back a resource a removal request had removed" do
      resource = memory.resources.first
      record = flag(resource)
      RemovalRequest.create!(memory_resource: resource, requester: onlooker, recipients: "admins", reason: "x").decide!("removed", by: admin)

      record.resolve!("dismissed", by: admin)

      expect(resource.reload).to be_hidden
    end

    it "resolves only once" do
      record = flag.tap { |f| f.resolve!("dismissed", by: admin) }

      expect { record.resolve!("acted", by: admin) }.to raise_error(Flag::AlreadyResolved)
    end
  end
end
