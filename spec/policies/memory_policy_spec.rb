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
      workspace.memberships.find_by(user: author).update_columns(discarded_at: Time.current)

      expect(policy(author, memory)).to have_attributes(update?: false, destroy?: false)
    end

    it "refuses the author from inside a different community" do
      memory
      Current.workspace = create(:workspace)

      expect(policy(author, memory)).to have_attributes(update?: false, destroy?: false)
    end
  end
end
