require "rails_helper"

RSpec.describe RemovalRequest, type: :model do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:author) { create(:membership, workspace: community, user: create(:user, first_name: "Juniper")).user }
  let(:requester) { create(:membership, workspace: community).user }
  let(:onlooker) { create(:membership, workspace: community).user }
  let(:memory) { create(:memory, workspace: community, author: author, visibility: "community") }
  let(:resource) { memory.resources.first }

  def ask(to: "both", about: resource, by: requester, reason: "It shows my house number")
    RemovalRequest.create!(memory_resource: about, requester: by, recipients: to, reason: reason)
  end

  describe "asking" do
    it "starts a 3-day clock" do
      freeze_time do
        expect(ask.due_at).to eq(3.days.from_now)
      end
    end

    it "needs a reason" do
      expect { ask(reason: " ") }.to raise_error(ActiveRecord::RecordInvalid, /reason/i)
    end

    it "is open to anyone who can see the resource, and no one else" do
      private_resource = create(:memory, workspace: community, author: author, visibility: "only_me").resources.first

      expect { ask(about: private_resource) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "isn't for your own resource; you change or remove it yourself" do
      expect { ask(by: author) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "is one request per person per resource, since asking takes it out of their sight" do
      ask

      expect { ask(to: "admins") }.to raise_error(ActiveRecord::RecordInvalid, /can see/)
    end

    it "sends a request about an anonymous memory through the admins, whoever the requester picked" do
      anonymous = create(:memory, workspace: community, author: author, visibility: "community", anonymous: true)

      request = ask(to: "author", about: anonymous.resources.first)

      expect(request).to have_attributes(recipients: "admins", reaches_author?: false)
    end

    it "keeps its reason encrypted at rest" do
      request = ask

      raw = RemovalRequest.connection.select_value("SELECT reason FROM removal_requests WHERE id = #{request.id}")
      expect(raw).not_to include("house number")
    end
  end

  describe "the requester" do
    it "stops seeing the resource at once, while everyone else still sees it" do
      ask

      expect(MemoryResource.visible_to(requester)).not_to include(resource)
      expect(MemoryResource.visible_to(onlooker)).to include(resource)
    end

    it "still doesn't see it once the request is answered" do
      ask(to: "admins").decide!("kept", by: admin)

      expect(MemoryResource.visible_to(requester)).not_to include(resource)
    end

    it "finds the outcome among their own requests" do
      ask(to: "admins").decide!("changed", by: admin)

      expect(RemovalRequest.made_by(requester).sole).to have_attributes(outcome: "changed")
    end
  end

  describe "who sees \"removal requested\"" do
    it "shows it to the author and the admins, and to nobody else" do
      ask

      expect([ author, admin, onlooker ].map { |viewer| resource.removal_requested_for?(viewer) }).to eq([ true, true, false ])
    end

    it "shows a request to the author only to the author" do
      ask(to: "author")

      expect([ author, admin ].map { |viewer| resource.removal_requested_for?(viewer) }).to eq([ true, false ])
    end

    it "shows a request to the admins only to the admins" do
      ask(to: "admins")

      expect([ author, admin ].map { |viewer| resource.removal_requested_for?(viewer) }).to eq([ false, true ])
    end

    it "stops showing it once answered" do
      ask(to: "admins").decide!("kept", by: admin)

      expect(resource.removal_requested_for?(admin)).to be(false)
    end

    it "shows an anonymous memory's request to its author only once an admin relays it" do
      anonymous = create(:memory, workspace: community, author: author, visibility: "community", anonymous: true).resources.first
      request = ask(about: anonymous)
      expect(anonymous.removal_requested_for?(author)).to be(false)

      request.relay!(by: admin)

      expect(anonymous.removal_requested_for?(author)).to be(true)
    end
  end

  describe "#decide!" do
    it "records who answered, when, and how" do
      request = ask(to: "admins")

      freeze_time do
        request.decide!("removed", by: admin)

        expect(request.reload).to have_attributes(outcome: "removed", decided_by: admin, decided_at: Time.current, open?: false)
      end
    end

    it "takes a removed resource out of everyone's sight but its author's" do
      ask(to: "admins").decide!("removed", by: admin)

      expect(MemoryResource.visible_to(onlooker)).not_to include(resource)
      expect(MemoryResource.visible_to(author)).to include(resource)
    end

    it "brings back a resource hidden urgently when the answer is kept" do
      request = ask(to: "admins")
      request.hide_now!(by: admin)
      expect(MemoryResource.visible_to(onlooker)).not_to include(resource)

      request.decide!("kept", by: admin)

      expect(MemoryResource.visible_to(onlooker)).to include(resource)
    end

    it "doesn't bring back a resource another request had removed" do
      ask(to: "admins").decide!("removed", by: admin)
      second = ask(to: "admins", by: onlooker.tap { resource.update_column(:hidden_at, nil) })
      resource.update_column(:hidden_at, Time.current)

      second.decide!("kept", by: admin)

      expect(resource.reload.hidden_at).to be_present
    end

    it "logs the decision where only admins read it, without the reason" do
      ask(to: "admins").decide!("removed", by: admin)

      entry = ActivityLog.find_by!(action: "removal_request.decided")
      expect(entry).to have_attributes(visibility: "admin", workspace_id: community.id)
      expect(entry.metadata).to include("outcome" => "removed", "decided_by" => admin.id)
      expect(entry.metadata.to_s).not_to include("house number")
    end

    it "answers only once" do
      request = ask(to: "admins")
      request.decide!("kept", by: admin)

      expect { request.decide!("removed", by: admin) }.to raise_error(RemovalRequest::AlreadyDecided)
    end

    it "refuses an outcome that isn't removed, changed or kept" do
      expect { ask(to: "admins").decide!("ignored", by: admin) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#hide_now!" do
    it "hides the resource from everyone but its author at once, and logs it" do
      ask(to: "admins").hide_now!(by: admin)

      expect(MemoryResource.visible_to(onlooker)).not_to include(resource)
      expect(MemoryResource.visible_to(author)).to include(resource)
      expect(ActivityLog.find_by!(action: "removal_request.hidden")).to have_attributes(visibility: "admin")
    end
  end

  describe ".overdue" do
    it "finds open requests past their 3 days" do
      late = ask(to: "admins")
      answered = ask(to: "admins", by: onlooker).tap { |request| request.decide!("kept", by: admin) }

      expect(RemovalRequest.overdue(now: 3.days.from_now + 1.minute)).to contain_exactly(late)
      expect(RemovalRequest.overdue(now: 2.days.from_now)).to be_empty
      expect(answered).not_to be_open
    end
  end
end
