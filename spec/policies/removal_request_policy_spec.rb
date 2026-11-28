require "rails_helper"

RSpec.describe RemovalRequestPolicy do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true).tap { |w| Current.workspace = w } }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:author) { create(:membership, workspace: community).user }
  let(:requester) { create(:membership, workspace: community).user }
  let(:onlooker) { create(:membership, workspace: community).user }
  let(:resource) { create(:memory, workspace: community, author: author, visibility: "community").resources.first }

  after { Current.workspace = nil }

  def ask(to:, about: resource)
    RemovalRequest.create!(memory_resource: about, requester: requester, recipients: to, reason: "Please take it down")
  end

  def policy(user, request)
    described_class.new(user, request)
  end

  describe "#create?" do
    it "lets a member who sees the resource ask, but not its author" do
      build = ->(user) { RemovalRequest.new(memory_resource: resource, requester: user, recipients: "both", reason: "x") }

      expect(policy(requester, build.call(requester)).create?).to be(true)
      expect(policy(author, build.call(author)).create?).to be(false)
    end

    it "refuses a resource from another community than the one at hand" do
      elsewhere = create(:workspace)
      create(:membership, workspace: elsewhere, user: requester)
      theirs = create(:memory, workspace: elsewhere, visibility: "community").resources.first

      request = RemovalRequest.new(memory_resource: theirs, requester: requester, recipients: "both", reason: "x")

      expect(policy(requester, request).create?).to be(false)
    end

    it "refuses asking in someone else's name" do
      request = RemovalRequest.new(memory_resource: resource, requester: onlooker, recipients: "both", reason: "x")

      expect(policy(requester, request).create?).to be(false)
    end
  end

  describe "#decide?" do
    it "lets the author answer a request sent only to them" do
      request = ask(to: "author")

      expect([ author, admin, onlooker ].map { |user| policy(user, request).decide? }).to eq([ true, false, false ])
    end

    it "leaves a request that reaches the admins to the admins" do
      %w[admins both].each do |to|
        request = ask(to: to)

        expect([ author, admin ].map { |user| policy(user, request).decide? }).to eq([ false, true ]), to
        request.destroy!
      end
    end

    it "keeps a blocked admin out while another admin is clear" do
      sage = create(:membership, :admin, workspace: community).user
      Block.create!(workspace: community, blocker: requester, blocked: admin)
      request = ask(to: "admins")

      expect([ admin, sage ].map { |user| policy(user, request).decide? }).to eq([ false, true ])
    end

    it "refuses a request already answered" do
      request = ask(to: "admins").tap { |r| r.decide!("kept", by: admin) }

      expect(policy(admin, request).decide?).to be(false)
    end
  end

  describe "#hide_now? and #relay?" do
    it "lets a handling admin hide at once, but not the author" do
      request = ask(to: "both")

      expect([ admin, author ].map { |user| policy(user, request).hide_now? }).to eq([ true, false ])
    end

    it "lets a handling admin relay an anonymous memory's request, once" do
      anonymous = create(:memory, workspace: community, author: author, visibility: "community", anonymous: true).resources.first
      request = ask(to: "admins", about: anonymous)

      expect([ admin, author ].map { |user| policy(user, request).relay? }).to eq([ true, false ])
      request.relay!(by: admin)
      expect(policy(admin, request).relay?).to be(false)
    end

    it "has nothing to relay on a memory with its author's name on it" do
      expect(policy(admin, ask(to: "admins")).relay?).to be(false)
    end
  end
end
