require "rails_helper"

RSpec.describe TagPolicy, :community_members do
  let(:community) { create(:workspace, max_members: 20).tap { |w| Current.workspace = w } }
  let(:author) { create(:membership, workspace: community).user }

  after { Current.workspace = nil }

  def memory(**attrs)
    create(:memory, workspace: community, author: author, visibility: "community", **attrs)
  end

  def new_tag(tagger, on:, person: nil, name: nil)
    Tag.new(memory_resource: on.resources.first, tagger: tagger, tagged_user: person, typed_name: name)
  end

  describe "#create?" do
    it "lets anyone who can see it tag someone who can too, by default" do
      viewer = community_member

      expect(described_class.new(viewer, new_tag(viewer, on: memory, person: community_member)).create?).to be true
      expect(described_class.new(viewer, new_tag(viewer, on: memory, name: "Coach Ellery")).create?).to be true
    end

    it "lets only the author tag when the author limits tagging" do
      limited = memory(tag_rule: "author")
      viewer = community_member

      expect(described_class.new(viewer, new_tag(viewer, on: limited, person: community_member)).create?).to be false
      expect(described_class.new(author, new_tag(author, on: limited, person: community_member)).create?).to be true
    end

    it "lets only the author widen the audience by tagging someone who can't see it yet" do
      named_only = memory(visibility: "specific_people")
      viewer = community_member
      MemoryAccess.create!(memory: named_only, user: viewer)
      outside = community_member

      expect(described_class.new(viewer, new_tag(viewer, on: named_only, person: outside)).create?).to be false
      expect(described_class.new(author, new_tag(author, on: named_only, person: outside)).create?).to be true
    end

    it "refuses someone who can't see the memory, a reader, or a guest" do
      hidden = memory(visibility: "only_me")
      stranger = community_member

      expect(described_class.new(stranger, new_tag(stranger, on: hidden, name: "x")).create?).to be false
      [ community_member(preset: "reader"), community_member(:viewer) ].each do |user|
        expect(described_class.new(user, new_tag(user, on: memory(visible_to_guests: true), name: "x")).create?).to be false
      end
    end

    it "refuses a tag on a memory from another community than the one in hand" do
      viewer = community_member
      tag = new_tag(viewer, on: memory, name: "x")
      elsewhere = create(:workspace)
      create(:membership, workspace: elsewhere, user: viewer)
      Current.workspace = elsewhere

      expect(described_class.new(viewer, tag).create?).to be false
    end

    it "refuses tagging on someone else's behalf" do
      viewer = community_member

      expect(described_class.new(viewer, new_tag(author, on: memory, name: "x")).create?).to be false
    end
  end

  describe "#update? (approve, remove my name, restore) and #destroy?" do
    let(:tagger) { community_member }
    let(:person) { community_member }
    let(:tag) { memory.resources.first.tag(person: person, by: tagger) }

    it "lets only the tagged person choose how they appear" do
      expect(described_class.new(person, tag).update?).to be true
      [ tagger, author, community_member(:admin), nil ].each do |user|
        expect(described_class.new(user, tag).update?).to be false
      end
    end

    it "lets whoever added it and the author delete it, and nobody else" do
      [ tagger, author ].each { |user| expect(described_class.new(user, tag).destroy?).to be true }
      [ person, community_member, community_member(:admin), nil ].each { |user| expect(described_class.new(user, tag).destroy?).to be false }
    end
  end
end
