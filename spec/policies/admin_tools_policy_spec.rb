require "rails_helper"

RSpec.describe "Admin moderation tools", type: :policy do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true).tap { |w| Current.workspace = w } }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:member) { create(:membership, workspace: community).user }
  let(:author) { create(:membership, workspace: community).user }

  after { Current.workspace = nil }

  describe MemoryPolicy, "#reveal_author?" do
    let(:anonymous) { create(:memory, workspace: community, author: author, visibility: "community", anonymous: true) }

    it "lets an admin reveal an anonymous memory's author, and nobody else" do
      expect([ admin, member ].map { |user| MemoryPolicy.new(user, anonymous).reveal_author? }).to eq([ true, false ])
    end

    it "has nothing to reveal on a named memory" do
      named = create(:memory, workspace: community, author: author, visibility: "community")

      expect(MemoryPolicy.new(admin, named).reveal_author?).to be(false)
    end
  end

  describe MembershipPolicy do
    it "lets an admin open a member's moderation history, but never their own" do
      target = community.memberships.find_by!(user: member)
      own = community.memberships.find_by!(user: admin)

      expect(MembershipPolicy.new(admin, target).moderation_history?).to be(true)
      expect(MembershipPolicy.new(admin, own).moderation_history?).to be(false)
      expect(MembershipPolicy.new(member, community.memberships.find_by!(user: author)).moderation_history?).to be(false)
    end

    it "lets an admin clear the memories of someone removed for cause, and only then" do
      target = community.memberships.find_by!(user: member)
      expect(MembershipPolicy.new(admin, target).clear_memories_for_cause?).to be(false)

      target.remove_for_cause!(by: admin, reason: "Threats")

      expect(MembershipPolicy.new(admin, target).clear_memories_for_cause?).to be(true)
      expect(MembershipPolicy.new(author, target).clear_memories_for_cause?).to be(false)
    end
  end
end
