require "rails_helper"

RSpec.describe Workspace, "#post_memory", type: :model do
  let(:workspace) { create(:workspace) }
  let(:author) { create(:membership, workspace: workspace).user }
  let(:reflection) { { kind: "written_reflection", body: "The lake froze the winter I arrived." } }

  def photo
    { kind: "photo", photo: fixture_file_upload("avatar.png", "image/png") }
  end

  it "saves a memory and its resources together, credited to the author" do
    memory = workspace.post_memory(author: author, resources: [ reflection, photo ])

    expect(memory).to be_persisted
    expect(memory.author).to eq(author)
    expect(memory.resources.map(&:kind)).to eq(%w[written_reflection photo])
    expect(memory.resources.map(&:contributor)).to all(eq(author))
  end

  it "keeps a new memory to its author until they share it" do
    memory = workspace.post_memory(author: author, resources: [ reflection ])

    expect(memory).to have_attributes(
      visibility: "only_me", comment_rule: "viewers", reflect_rule: "viewers",
      tag_rule: "viewers", visible_to_guests: false, anonymous: false
    )
  end

  it "saves nothing when a resource is invalid" do
    memory = nil

    expect {
      memory = workspace.post_memory(author: author, resources: [ reflection, { kind: "written_reflection", body: "" } ])
    }.not_to change { [ Memory.count, MemoryResource.count ] }

    expect(memory).not_to be_persisted
  end

  it "refuses a memory with nothing in it" do
    memory = workspace.post_memory(author: author, resources: [])

    expect(memory.errors).to be_added(:base, :needs_a_resource)
  end

  it "refuses an author who isn't a member of the community" do
    stranger = create(:user)

    memory = workspace.post_memory(author: stranger, resources: [ reflection ])

    expect(memory.errors).to be_added(:author, :not_a_member)
  end

  it "refuses an author who has left the community" do
    left = create(:membership, :deactivated, workspace: workspace).user

    expect(workspace.post_memory(author: left, resources: [ reflection ]).errors).to be_added(:author, :not_a_member)
  end

  it "refuses new memories in an archived community" do
    workspace.update_columns(archived_at: Time.current)

    memory = workspace.post_memory(author: author, resources: [ reflection ])

    expect(memory.errors).to be_added(:base, :community_read_only)
  end

  it "refuses new memories in a suspended or deleted community" do
    [ { suspended_at: Time.current }, { discarded_at: Time.current } ].each do |state|
      community = create(:workspace).tap { |w| w.update_columns(state) }
      member = create(:membership, workspace: community).user

      memory = community.post_memory(author: member, resources: [ reflection ])

      expect(memory.errors).to be_added(:base, :community_read_only), state.keys.first.to_s
    end
  end

  describe "anonymous posts" do
    it "accepts one where the community allows anonymous posting" do
      workspace.update!(anonymous_posting: true)

      memory = workspace.post_memory(author: author, anonymous: true, resources: [ reflection ])

      expect(memory).to be_persisted
      expect(memory.author).to eq(author)
    end

    it "refuses one where the community does not" do
      memory = workspace.post_memory(author: author, anonymous: true, resources: [ reflection ])

      expect(memory.errors).to be_added(:anonymous, :not_allowed_here)
    end
  end

  it "starts communities with anonymous posting off" do
    expect(create(:workspace).anonymous_posting).to be false
  end
end
