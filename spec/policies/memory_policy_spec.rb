require "rails_helper"

RSpec.describe MemoryPolicy do
  let(:workspace) { create(:workspace).tap { |w| Current.workspace = w } }

  after { Current.workspace = nil }

  def member(*traits, **attrs)
    create(:membership, *traits, workspace: workspace, **attrs).user
  end

  def policy(user, memory = workspace.memories.build)
    described_class.new(user, memory)
  end

  describe "#create?" do
    it "lets contributors, admins and the owner post" do
      [ member(preset: "contributor"), member(:admin), member(:owner) ].each do |user|
        expect(policy(user).create?).to be true
      end
    end

    it "refuses participants, readers, guests and people who have left" do
      [ member(preset: "participant"), member(preset: "reader"), member(:viewer), member(:deactivated) ].each do |user|
        expect(policy(user).create?).to be false
      end
    end

    it "refuses a stranger to the community" do
      expect(policy(create(:user)).create?).to be false
    end

    it "refuses everyone in an archived, suspended or deleted community" do
      owner = member(:owner)

      %i[archived_at suspended_at discarded_at].each do |column|
        workspace.update_columns(archived_at: nil, suspended_at: nil, discarded_at: nil, column => Time.current)

        expect(policy(owner).create?).to be(false), column.to_s
      end
    end
  end

  describe "#update? and #destroy?" do
    let(:author) { member }
    let(:memory) { create(:memory, workspace: workspace, author: author) }

    it "lets the author change or delete their memory" do
      expect(policy(author, memory)).to have_attributes(update?: true, destroy?: true)
    end

    it "refuses an admin or the owner, who don't own it" do
      [ member(:admin), member(:owner) ].each do |user|
        expect(policy(user, memory)).to have_attributes(update?: false, destroy?: false)
      end
    end

    it "refuses the author once they have left the community" do
      memory
      workspace.memberships.find_by(user: author).leave!

      expect(policy(author, memory)).to have_attributes(update?: false, destroy?: false)
    end

    context "when an admin has removed the author, who now reaches it from outside the community" do
      before do
        memory
        workspace.memberships.find_by(user: author).deactivate!(removed_by: member(:admin))
        Current.workspace = nil
      end

      it "lets them delete it from their exit page, but not change it" do
        travel(89.days) { expect(policy(author, memory)).to have_attributes(update?: false, destroy?: true) }
      end

      it "stops once the 90 days are up" do
        travel(91.days) { expect(policy(author, memory).destroy?).to be(false) }
      end
    end

    context "when an admin has removed the author for cause" do
      before do
        memory
        workspace.memberships.find_by(user: author).remove_for_cause!(by: member(:admin), reason: "Threats in reflections")
      end

      it "doesn't let them delete it, even from their exit page" do
        Current.workspace = nil

        expect(policy(author, memory).destroy?).to be(false)
      end

      it "lets an admin delete it, and nobody else" do
        expect(policy(member(:admin), memory).destroy?).to be(true)
        expect(policy(member, memory).destroy?).to be(false)
      end
    end

    it "doesn't let an admin delete the memory of someone who simply left" do
      memory
      workspace.memberships.find_by(user: author).leave!

      expect(policy(member(:admin), memory).destroy?).to be(false)
    end

    it "refuses the author from inside a different community" do
      memory
      Current.workspace = create(:workspace)

      expect(policy(author, memory)).to have_attributes(update?: false, destroy?: false)
    end
  end
end
