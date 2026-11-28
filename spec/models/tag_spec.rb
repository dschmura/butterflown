require "rails_helper"

RSpec.describe Tag, type: :model do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true) }
  let(:author) { create(:membership, workspace: community).user }
  let(:memory) { create(:memory, workspace: community, author: author, visibility: "community") }
  let(:resource) { memory.resources.first }

  def member(tag_setting: "approve")
    create(:membership, workspace: community, tag_setting: tag_setting).user
  end

  describe "a new tag's state" do
    it "waits for someone who approves their tags" do
      tag = resource.tag(person: member, by: author)

      expect(tag).to have_attributes(state: "pending", persisted?: true)
      expect(tag.expires_at).to be_within(1.minute).of(14.days.from_now)
    end

    it "shows at once for someone okay appearing" do
      expect(resource.tag(person: member(tag_setting: "okay"), by: author).state).to eq("approved")
    end

    it "shows at once when you tag yourself" do
      tagger = member

      expect(resource.tag(person: tagger, by: tagger).state).to eq("approved")
    end

    it "shows a typed name at once, granting nothing" do
      tag = resource.tag(name: "Coach Ellery", by: author)

      expect(tag).to have_attributes(state: "approved", tagged_user: nil, typed_name: "Coach Ellery")
    end

    it "starts no clock while the memory is private to its author" do
      memory.update_columns(visibility: "only_me")

      expect(resource.tag(person: member, by: author).expires_at).to be_nil
    end
  end

  describe "refusals" do
    it "refuses a tag on an anonymous memory" do
      anonymous = create(:memory, workspace: community, author: author, anonymous: true)

      tag = anonymous.resources.first.tag(person: member, by: author)

      expect(tag.errors).to be_added(:base, :anonymous_memory)
    end

    it "refuses tagging someone who isn't a member, or has left, by account" do
      leaver = create(:membership, :deactivated, workspace: community).user

      [ create(:user), leaver ].each do |person|
        expect(resource.tag(person: person, by: author).errors).to be_added(:tagged_user, :not_taggable)
      end
    end

    it "refuses both a person and a typed name, or neither" do
      expect(resource.tag(person: member, name: "Someone", by: author).errors).to be_added(:base, :person_or_name)
      expect(resource.tag(by: author).errors).to be_added(:base, :person_or_name)
    end

    it "refuses tagging across a block, either way, with the same answer as for a non-member" do
      blocker = member
      blocked = member
      Block.create!(workspace: community, blocker: blocker, blocked: blocked)

      expect(resource.tag(person: blocked, by: blocker).errors).to be_added(:tagged_user, :not_taggable)
      expect(resource.tag(person: blocker, by: blocked).errors).to be_added(:tagged_user, :not_taggable)
    end

    it "tags a person once per resource, in the database too" do
      person = member
      resource.tag(person: person, by: author)

      expect(resource.tag(person: person, by: author).errors.of_kind?(:tagged_user_id, :taken)).to be true
      expect { Tag.new(memory_resource: resource, tagged_user: person, tagger: author, state: "approved", state_changed_at: Time.current).save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "the tagged person's choices" do
    let(:person) { member }
    let(:tag) { resource.tag(person: person, by: author) }

    it "approves, removes and restores, with no say from the author" do
      tag.approve!
      expect(tag.reload.state).to eq("approved")

      tag.unname!
      expect(tag.reload.state).to eq("unnamed")

      tag.restore!
      expect(tag.reload.state).to eq("approved")
    end

    it "shows the name only once approved" do
      expect(tag.name_shown?).to be false

      tag.approve!

      expect(tag.name_shown?).to be true
    end

    it "reads as unnamed once tagger and tagged have a block between them" do
      tag.approve!
      expect(tag.name_shown?).to be true

      Block.create!(workspace: community, blocker: person, blocked: author)

      expect(tag.reload.name_shown?).to be false
    end

    it "reads as unnamed under an everywhere block made in another community, and not under a local one there" do
      tag.approve!
      other = create(:workspace, max_members: 20)
      [ person, author ].each { |user| create(:membership, workspace: other, user: user) }

      Block.create!(workspace: other, blocker: person, blocked: author)
      expect(tag.reload.name_shown?).to be true

      Block.find_by!(workspace: other).update!(everywhere: true)
      expect(tag.reload.name_shown?).to be false
    end

    it "always shows a typed name" do
      expect(resource.tag(name: "Coach Ellery", by: author).name_shown?).to be true
    end
  end

  describe ".lapse_overdue" do
    it "turns pending tags past their 14 days unnamed, and leaves the rest" do
      overdue = resource.tag(person: member, by: author).tap { |t| t.update_columns(expires_at: 1.hour.ago) }
      waiting = resource.tag(person: member, by: author)
      approved = resource.tag(person: member(tag_setting: "okay"), by: author)
      memory.update_columns(visibility: "only_me")
      draft = resource.tag(person: member, by: author)

      Tag.lapse_overdue(now: Time.current)

      expect([ overdue, waiting, approved, draft ].map { |t| t.reload.state }).to eq(%w[unnamed pending approved pending])
    end
  end

  describe "sight" do
    it "lets a tag from the author keep someone in the audience, and a tag from anyone else not" do
      viewer = member
      by_author = member
      by_viewer = member
      resource.tag(person: by_author, by: author)
      resource.tag(person: by_viewer, by: viewer)

      memory.update!(visibility: "specific_people")

      expect(Memory.visible_to(by_author)).to include(memory)
      expect(Memory.visible_to(by_viewer)).not_to include(memory)
      expect(Memory.visible_to(viewer)).not_to include(memory)
    end

    it "keeps a memory with tags from becoming anonymous" do
      resource.tag(person: member, by: author)

      expect(memory.update(anonymous: true)).to be false
      expect(memory.errors).to be_added(:anonymous, :has_tags)
    end
  end

  describe ".visible_to" do
    it "lists only tags on memories the viewer can see" do
      person = member
      onlooker = member
      seen = resource.tag(person: person, by: author)
      private_memory = create(:memory, workspace: community, author: author, visibility: "only_me")
      hidden = private_memory.resources.first.tag(person: person, by: author)

      expect(Tag.visible_to(onlooker)).to contain_exactly(seen)
      expect(Tag.visible_to(author)).to contain_exactly(seen, hidden)
      expect(Tag.visible_to(nil)).to be_empty
    end
  end

  it "stores a typed name encrypted" do
    tag = resource.tag(name: "Coach Ellery", by: author)

    stored = Tag.connection.select_value("SELECT typed_name FROM tags WHERE id = #{tag.id}")

    expect(stored).to be_present
    expect(stored).not_to include("Ellery")
  end

  it "leaves no trace in the community's activity feed" do
    person = member
    resource

    expect { resource.tag(person: person, by: author) }.not_to change(ActivityLog, :count)
  end
end
