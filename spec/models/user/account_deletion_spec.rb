require "rails_helper"

RSpec.describe User, type: :model do
  let(:community) { create(:workspace, max_members: 20) }
  let(:other_community) { create(:workspace, max_members: 20) }
  let(:person) { create(:user, first_name: "Wren", last_name: "Hollis", email_address: "wren@example.test", password: "a long passphrase here") }
  let!(:here) { create(:membership, workspace: community, user: person) }
  let!(:there) { create(:membership, workspace: other_community, user: person) }
  let(:neighbour) { create(:membership, workspace: community).user }

  def memory_of(author, workspace, visibility)
    create(:memory, workspace: workspace, author: author, visibility: visibility)
  end

  def delete_after_the_hold(user = person, remove_name: false)
    user.request_deletion!(remove_name: remove_name)
    user.complete_deletion!(now: User::DELETION_HELD_FOR.from_now + 1.minute)
  end

  describe "#request_deletion!" do
    it "leaves every community at once, as someone who left" do
      person.request_deletion!

      expect([ here, there ].map(&:reload)).to all(have_attributes(discarded?: true, departure: "left"))
      expect(person.reload).to have_attributes(deletion_pending?: true, deleted?: false)
    end

    it "removes their name from what they shared at once, when they ask" do
      shared = memory_of(person, community, "community")

      person.request_deletion!(remove_name: true)

      expect(shared.reload.credit).to have_attributes(name: nil, former_member?: true)
    end

    it "signs them out everywhere, and keeps what they sign in with so they can cancel" do
      person.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", last_active_at: Time.current)

      person.request_deletion!

      expect(person.sessions.count).to eq(0)
      expect(person.reload).to have_attributes(email_address: "wren@example.test", suspended?: false)
      expect(person.authentications.count).to be_positive
    end

    it "keeps their private memories through the hold" do
      private_memory = memory_of(person, community, "only_me")

      person.request_deletion!

      expect(Memory.exists?(private_memory.id)).to be(true)
    end

    it "refuses, and changes nothing, while they are a community's only owner" do
      create(:membership, :owner, workspace: create(:workspace), user: person)

      expect { person.request_deletion! }.to raise_error(Membership::LastOwner)
      expect(person.reload.deletion_pending?).to be(false)
      expect(here.reload.kept?).to be(true)
    end

    it "goes ahead when the community has another owner" do
      owned = create(:workspace)
      create(:membership, :owner, workspace: owned, user: person)
      create(:membership, :owner, workspace: owned)

      person.request_deletion!

      expect(person.reload.deletion_pending?).to be(true)
    end

    it "doesn't restart the clock when asked again" do
      person.request_deletion!
      requested_at = person.reload.deletion_requested_at

      travel(1.day) { person.request_deletion!(remove_name: true) }

      expect(person.reload).to have_attributes(deletion_requested_at: requested_at, deletion_removes_name: false)
    end
  end

  describe "#cancel_deletion!" do
    it "brings them back to every community the request took them out of, by name" do
      person.request_deletion!(remove_name: true)

      person.cancel_deletion!

      expect([ here, there ].map(&:reload)).to all(have_attributes(kept?: true, departure: nil, name_removed?: false))
      expect(person.reload).to have_attributes(deletion_pending?: false, deletion_removes_name: false)
    end

    it "skips a community that was deleted, suspended or filled up during the hold" do
      deleted, suspended, full = Array.new(3) { create(:workspace, max_members: 2) }
      memberships = [ deleted, suspended, full ].map { |workspace| create(:membership, workspace: workspace, user: person) }
      person.request_deletion!
      deleted.update_column(:discarded_at, Time.current)
      suspended.update_column(:suspended_at, Time.current)
      create_list(:membership, 2, workspace: full)

      person.cancel_deletion!

      expect(memberships.map(&:reload)).to all(have_attributes(discarded?: true))
      expect(here.reload.kept?).to be(true)
    end

    it "leaves alone a community they had left before asking" do
      left_before = create(:membership, workspace: create(:workspace), user: person).tap(&:leave!)
      travel(1.minute) { person.request_deletion! }

      person.cancel_deletion!

      expect(left_before.reload.discarded?).to be(true)
    end

    it "does nothing for an account that isn't pending deletion" do
      expect { person.cancel_deletion! }.not_to(change { [ person.reload.attributes, here.reload.attributes ] })
    end
  end

  describe ".deletion_due" do
    it "finds accounts whose 30 days are up, and no others" do
      person.request_deletion!
      later = create(:user)
      travel(1.day) { later.request_deletion! }

      expect(User.deletion_due(now: 30.days.from_now + 1.minute)).to contain_exactly(person)
      expect(User.deletion_due(now: 30.days.from_now - 1.minute)).to be_empty
    end
  end

  describe "#complete_deletion!" do
    it "does nothing before the 30 days are up" do
      person.request_deletion!

      person.complete_deletion!(now: 29.days.from_now)

      expect(person.reload).to have_attributes(deleted?: false, email_address: "wren@example.test")
    end

    it "does nothing once they cancelled" do
      person.request_deletion!
      person.cancel_deletion!

      person.complete_deletion!(now: 31.days.from_now)

      expect(person.reload.deleted?).to be(false)
    end

    it "keeps shared memories, credited by name to a former member" do
      shared = memory_of(person, community, "community")

      delete_after_the_hold

      expect(Memory.visible_to(neighbour)).to include(shared)
      expect(shared.reload.credit).to have_attributes(name: "Wren Hollis", former_member?: true)
    end

    it "deletes private memories, in every community, with their resources" do
      private_here = memory_of(person, community, "only_me")
      private_there = memory_of(person, other_community, "only_me")

      expect { delete_after_the_hold }.to change(MemoryResource, :count).by(-2)
      expect(Memory.where(id: [ private_here, private_there ])).to be_empty
    end

    it "removes their name everywhere when they asked, including communities they had already left" do
      left_before = create(:membership, workspace: create(:workspace), user: person).tap(&:leave!)
      shared = memory_of(person, community, "community")

      delete_after_the_hold(remove_name: true)

      expect([ here, there, left_before ].map(&:reload)).to all(have_attributes(name_removed?: true))
      expect(shared.reload.credit).to have_attributes(name: nil, former_member?: true)
      expect(person.reload).to have_attributes(first_name: nil, last_name: nil)
    end

    it "keeps their name on the account when they didn't ask to remove it" do
      delete_after_the_hold

      expect(person.reload.full_name).to eq("Wren Hollis")
    end

    it "takes them out again of a community an admin brought them back to during the hold" do
      person.request_deletion!
      here.reactivate!(granted_by: create(:membership, :admin, workspace: community).user)

      person.complete_deletion!(now: 31.days.from_now)

      expect(here.reload).to have_attributes(discarded?: true, departure: "left")
    end

    it "unnames pending tags naming them, and keeps approved ones and the tags they made" do
      pending = memory_of(neighbour, community, "community").resources.first.tag(person: person, by: neighbour)
      approved = memory_of(neighbour, community, "community").resources.first.tag(person: person, by: neighbour).tap(&:approve!)
      their_own = memory_of(person, community, "community").resources.first.tag(person: neighbour, by: person)

      delete_after_the_hold

      expect(pending.reload.state).to eq("unnamed")
      expect(approved.reload.state).to eq("approved")
      expect(Tag.exists?(their_own.id)).to be(true)
    end

    it "leaves nothing to sign in with, and frees the email for a new account" do
      create(:webauthn_credential, user: person)
      expect([ person.authentications, person.webauthn_credentials ].map(&:count)).to all(be_positive)

      delete_after_the_hold

      expect(person.reload).to have_attributes(deleted?: true, deletion_pending?: false, password_digest: nil, pending_email: nil, webauthn_handle: nil)
      expect(person.email_address).not_to include("wren")
      expect([ person.sessions, person.authentications, person.webauthn_credentials ].map(&:count)).to all(eq(0))
      expect(User.find_by(email_address: "wren@example.test")).to be_nil
      expect(PasswordSignIn.new(email_address: "wren@example.test", password: "a long passphrase here").user).to be_nil
      expect(create(:user, email_address: "wren@example.test").id).not_to eq(person.id)
    end

    it "refuses a sign-in or session that raced the deletion, as every guard asks suspended?" do
      delete_after_the_hold

      expect(person.reload.suspended?).to be(true)
    end

    it "revokes pending invitations and magic links sent to the old email, so it can't rejoin a new account" do
      invitation = create(:invitation, invitable: community, email: "wren@example.test")
      MagicLinkToken.create_for_email("wren@example.test")

      delete_after_the_hold

      expect(invitation.reload.status).to eq("revoked")
      expect(MagicLinkToken.where(email: "wren@example.test")).to be_empty
    end

    it "ends what the account was granted: operator status, client access, being named on memories" do
      operatorship = Operatorship.grant!(user: person)
      create(:client_access, user: person)
      expect(person.client_accesses.count).to eq(1)
      named_on = memory_of(neighbour, community, "specific_people").tap { |memory| memory.accesses.create!(user: person) }

      delete_after_the_hold

      expect(operatorship.reload.discarded?).to be(true)
      expect(person.client_accesses.count).to eq(0)
      expect(named_on.accesses.where(user: person)).to be_empty
    end

    it "takes their name off their personal workspace when they asked" do
      workspace = person.personal_workspace
      skip "the factory user has no personal workspace" if workspace.nil?

      delete_after_the_hold(remove_name: true)

      expect(workspace.reload.name).not_to include("Wren")
    end

    it "takes their picture with it" do
      person.avatar.attach(io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")), filename: "a.png", content_type: "image/png")

      delete_after_the_hold

      expect(person.reload.avatar).not_to be_attached
    end

    it "gives every tombstone its own placeholder email, unrelated to the old one" do
      other = create(:user)
      [ person, other ].each { |user| delete_after_the_hold(user) }

      expect(person.reload.email_address).not_to eq(other.reload.email_address)
    end

    it "keeps a removal for cause as it was, with their named memories still hidden" do
      admin = create(:membership, :admin, workspace: community).user
      shared = memory_of(person, community, "community")
      here.remove_for_cause!(by: admin, reason: "Threats")

      delete_after_the_hold

      expect(here.reload.departure).to eq("removed_for_cause")
      expect(Memory.visible_to(neighbour)).not_to include(shared)
    end

    it "does nothing the second time" do
      delete_after_the_hold

      expect { person.complete_deletion!(now: 60.days.from_now) }.not_to(change { person.reload.attributes })
    end
  end

  it "never lets a deleted account's row be destroyed, which would take approved tags with it" do
    delete_after_the_hold

    expect(person.reload.destroy).to be(false)
    expect(User.exists?(person.id)).to be(true)
  end
end
