require "rails_helper"

RSpec.describe Membership, type: :model do
  let(:community) { create(:workspace, max_members: 20) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:membership) { create(:membership, workspace: community) }
  let(:person) { membership.user }

  describe "how someone left" do
    it "records leaving, with their name kept unless they ask otherwise" do
      membership.leave!

      expect(membership.reload).to have_attributes(discarded?: true, departure: "left", name_removed?: false)
    end

    it "records the choice to remove their name" do
      membership.leave!(remove_name: true)

      expect(membership.reload).to have_attributes(departure: "left", name_removed?: true)
    end

    it "records removal when someone else ends the membership" do
      membership.deactivate!(removed_by: admin)

      expect(membership.reload).to have_attributes(departure: "removed", name_removed?: false)
    end

    it "records leaving when the template's own door is used by the member themselves" do
      membership.deactivate!(removed_by: person)

      expect(membership.reload.departure).to eq("left")
    end

    it "treats an ending with no one named as a removal" do
      membership.deactivate!

      expect(membership.reload.departure).to eq("removed")
    end

    it "clears how they left, and their name choice, when they come back" do
      membership.leave!(remove_name: true)

      membership.reactivate!(granted_by: admin)

      expect(membership.reload).to have_attributes(kept?: true, departure: nil, name_removed?: false)
    end

    it "keeps how they left, and their name choice, out of the community's activity feed" do
      membership.leave!(remove_name: true)
      membership.reactivate!(granted_by: admin)

      changes = ActivityLog.where(trackable: membership, action: "membership.updated").map { |row| row.metadata["changes"] }
      expect(changes).to all(include("discarded_at"))
      expect(changes.flat_map(&:keys)).not_to include("departure", "name_removed")
    end

    it "changes nothing when someone already gone leaves again" do
      membership.leave!

      membership.leave!(remove_name: true)

      expect(membership).to have_attributes(name_removed?: false, changed?: false)
    end

    it "keeps an owner who is the last one from leaving" do
      owner = create(:membership, :owner, workspace: create(:workspace))

      expect { owner.leave! }.to raise_error(Membership::LastOwner)
      expect(owner.reload).to have_attributes(kept?: true, departure: nil)
    end

    it "refuses, in the database, a departure on someone still a member" do
      expect { membership.update_column(:departure, "left") }.to raise_error(ActiveRecord::StatementInvalid, /departure/)
    end

    it "refuses, in the database, a departure it doesn't know" do
      membership.leave!

      expect { membership.update_column(:departure, "vanished") }.to raise_error(ActiveRecord::StatementInvalid, /departure/)
    end
  end

  describe "tags naming the person, when they go" do
    let(:author) { create(:membership, workspace: community).user }
    let(:resource) { create(:memory, workspace: community, author: author, visibility: "community").resources.first }

    it "turns their pending tags in this community unnamed, as of when they left" do
      tag = resource.tag(person: person, by: author)
      expect(tag.expires_at).to be_present

      travel(3.days) { membership.leave! }

      expect(tag.reload).to have_attributes(state: "unnamed", expires_at: nil)
      expect(tag.state_changed_at).to be_within(1.minute).of(3.days.from_now)
    end

    it "does the same when an admin removes them" do
      tag = resource.tag(person: person, by: author)

      membership.deactivate!(removed_by: admin)

      expect(tag.reload.state).to eq("unnamed")
    end

    it "leaves their approved tags approved" do
      tag = resource.tag(person: person, by: author)
      tag.approve!

      membership.leave!

      expect(tag.reload.state).to eq("approved")
    end

    it "leaves their pending tags in another community alone" do
      elsewhere = create(:workspace)
      create(:membership, workspace: elsewhere, user: person)
      other_author = create(:membership, workspace: elsewhere).user
      other_resource = create(:memory, workspace: elsewhere, author: other_author, visibility: "community").resources.first
      tag = other_resource.tag(person: person, by: other_author)

      membership.leave!

      expect(tag.reload.state).to eq("pending")
    end

    it "leaves other people's pending tags alone" do
      someone = create(:membership, workspace: community).user
      tag = resource.tag(person: someone, by: author)

      membership.leave!

      expect(tag.reload.state).to eq("pending")
    end
  end
end
