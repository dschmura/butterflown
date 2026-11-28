require "rails_helper"

RSpec.describe Memory::Credit, type: :model do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:author_membership) { create(:membership, workspace: community, user: create(:user, first_name: "Wren", last_name: "Hollis")) }
  let(:author) { author_membership.user }
  let(:memory) { create(:memory, workspace: community, author: author, visibility: "community") }

  it "names a member" do
    expect(memory.credit).to have_attributes(name: "Wren Hollis", former_member?: false, anonymous?: false)
  end

  it "names someone who left, as a former member" do
    memory
    author_membership.leave!

    expect(memory.credit).to have_attributes(name: "Wren Hollis", former_member?: true)
  end

  it "credits someone who removed their name as a former member, with no name" do
    memory
    author_membership.leave!(remove_name: true)

    expect(memory.credit).to have_attributes(name: nil, former_member?: true, anonymous?: false)
  end

  it "keeps the name of someone an admin removed" do
    memory
    author_membership.deactivate!(removed_by: admin)

    expect(memory.credit).to have_attributes(name: "Wren Hollis", former_member?: true)
  end

  it "names them as a member again once they come back" do
    memory
    author_membership.leave!(remove_name: true)
    author_membership.reactivate!(granted_by: admin)

    expect(memory.credit).to have_attributes(name: "Wren Hollis", former_member?: false)
  end

  it "keeps an anonymous memory anonymous after its author leaves, with no former-member label" do
    anonymous = create(:memory, workspace: community, author: author, visibility: "community", anonymous: true)
    author_membership.leave!

    expect(anonymous.credit).to have_attributes(name: nil, former_member?: false, anonymous?: true)
  end

  it "credits someone with no membership row at all by name, as a former member" do
    memory
    author_membership.delete

    expect(memory.credit).to have_attributes(name: "Wren Hollis", former_member?: true)
  end

  it "answers per community: a member here who left elsewhere is still a member here" do
    elsewhere = create(:workspace)
    create(:membership, workspace: elsewhere, user: author).leave!

    expect(memory.credit.former_member?).to be(false)
  end

  describe "a resource's credit" do
    let(:contributor_membership) { create(:membership, workspace: community, user: create(:user, first_name: "Odile", last_name: "Marsh")) }
    let(:perspective) { create(:memory_resource, memory: memory, contributor: contributor_membership.user) }

    it "names its contributor, a former member once they leave" do
      perspective
      contributor_membership.leave!

      expect(perspective.credit).to have_attributes(name: "Odile Marsh", former_member?: true)
    end

    it "keeps the author's own resource on an anonymous memory anonymous" do
      anonymous = create(:memory, workspace: community, author: author, visibility: "community", anonymous: true)

      expect(anonymous.resources.first.credit.anonymous?).to be(true)
    end

    it "names someone else's perspective on an anonymous memory; the memory's anonymity is its author's" do
      anonymous = create(:memory, workspace: community, author: author, visibility: "community", anonymous: true)
      other = create(:memory_resource, memory: anonymous, contributor: contributor_membership.user)

      expect(other.credit.name).to eq("Odile Marsh")
    end
  end
end
