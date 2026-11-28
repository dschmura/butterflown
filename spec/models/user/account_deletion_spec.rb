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

  describe "#delete_account!" do
    it "leaves every community, as someone who left" do
      person.delete_account!

      expect([ here, there ].map(&:reload)).to all(have_attributes(discarded?: true, departure: "left"))
    end

    it "keeps shared memories, credited by name to a former member" do
      shared = memory_of(person, community, "community")

      person.delete_account!

      expect(Memory.visible_to(neighbour)).to include(shared)
      expect(shared.reload.credit).to have_attributes(name: "Wren Hollis", former_member?: true)
    end

    it "deletes private memories now, in every community, with their resources" do
      private_here = memory_of(person, community, "only_me")
      private_there = memory_of(person, other_community, "only_me")

      expect { person.delete_account! }.to change(MemoryResource, :count).by(-2)
      expect(Memory.where(id: [ private_here, private_there ])).to be_empty
    end

    it "removes their name everywhere when they ask, including communities they had already left" do
      left_before = create(:membership, workspace: create(:workspace), user: person).tap(&:leave!)
      shared = memory_of(person, community, "community")

      person.delete_account!(remove_name: true)

      expect([ here, there, left_before ].map(&:reload)).to all(have_attributes(name_removed?: true))
      expect(shared.reload.credit).to have_attributes(name: nil, former_member?: true)
      expect(person.reload).to have_attributes(first_name: nil, last_name: nil)
    end

    it "keeps their name on the account when they don't ask to remove it" do
      person.delete_account!

      expect(person.reload.full_name).to eq("Wren Hollis")
    end

    it "unnames pending tags naming them, and keeps approved ones and the tags they made" do
      pending = memory_of(neighbour, community, "community").resources.first.tag(person: person, by: neighbour)
      approved = memory_of(neighbour, community, "community").resources.first.tag(person: person, by: neighbour).tap(&:approve!)
      their_own = memory_of(person, community, "community").resources.first.tag(person: neighbour, by: person)

      person.delete_account!

      expect(pending.reload.state).to eq("unnamed")
      expect(approved.reload.state).to eq("approved")
      expect(Tag.exists?(their_own.id)).to be(true)
    end

    it "leaves nothing to sign in with, and frees the email for a new account" do
      create(:webauthn_credential, user: person)
      person.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", last_active_at: Time.current)
      expect([ person.sessions, person.authentications, person.webauthn_credentials ].map(&:count)).to all(be_positive)

      person.delete_account!

      expect(person.reload).to have_attributes(deleted?: true, password_digest: nil, pending_email: nil, webauthn_handle: nil)
      expect(person.email_address).not_to include("wren")
      expect([ person.sessions, person.authentications, person.webauthn_credentials ].map(&:count)).to all(eq(0))
      expect(User.find_by(email_address: "wren@example.test")).to be_nil
      expect(PasswordSignIn.new(email_address: "wren@example.test", password: "a long passphrase here").user).to be_nil
      expect(create(:user, email_address: "wren@example.test").id).not_to eq(person.id)
    end

    it "refuses a sign-in or session that raced the deletion, as every guard asks suspended?" do
      person.delete_account!

      expect(person.reload.suspended?).to be(true)
    end

    it "revokes pending invitations and magic links sent to the old email, so it can't rejoin a new account" do
      invitation = create(:invitation, invitable: community, email: "wren@example.test")
      MagicLinkToken.create_for_email("wren@example.test")

      person.delete_account!

      expect(invitation.reload.status).to eq("revoked")
      expect(MagicLinkToken.where(email: "wren@example.test")).to be_empty
    end

    it "ends what the account was granted: operator status, client access, being named on memories" do
      operatorship = Operatorship.grant!(user: person)
      create(:client_access, user: person)
      expect(person.client_accesses.count).to eq(1)
      named_on = memory_of(neighbour, community, "specific_people").tap { |memory| memory.accesses.create!(user: person) }

      person.delete_account!

      expect(operatorship.reload.discarded?).to be(true)
      expect(person.client_accesses.count).to eq(0)
      expect(named_on.accesses.where(user: person)).to be_empty
    end

    it "takes their name off their personal workspace when they remove it" do
      workspace = person.personal_workspace
      skip "the factory user has no personal workspace" if workspace.nil?

      person.delete_account!(remove_name: true)

      expect(workspace.reload.name).not_to include("Wren")
    end

    it "takes their picture with it" do
      person.avatar.attach(io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")), filename: "a.png", content_type: "image/png")

      person.delete_account!

      expect(person.reload.avatar).not_to be_attached
    end

    it "gives every tombstone its own placeholder email, unrelated to the old one" do
      other = create(:user)
      [ person, other ].each(&:delete_account!)

      expect(person.reload.email_address).not_to eq(other.reload.email_address)
    end

    it "refuses, and changes nothing, while they are a community's only owner" do
      owned = create(:workspace)
      create(:membership, :owner, workspace: owned, user: person)
      memory_of(person, community, "only_me")

      expect { person.delete_account! }.to raise_error(Membership::LastOwner)
      expect(person.reload).to have_attributes(deleted?: false, email_address: "wren@example.test")
      expect(here.reload.kept?).to be(true)
      expect(Memory.where(author: person).count).to eq(1)
    end

    it "keeps a removal for cause as it was, with their shared memories still hidden" do
      admin = create(:membership, :admin, workspace: community).user
      shared = memory_of(person, community, "community")
      here.remove_for_cause!(by: admin, reason: "Threats")

      person.delete_account!

      expect(here.reload.departure).to eq("removed_for_cause")
      expect(Memory.visible_to(neighbour)).not_to include(shared)
    end

    it "does nothing the second time" do
      person.delete_account!

      expect { person.delete_account!(remove_name: true) }.not_to(change { person.reload.attributes })
    end
  end

  it "never lets a deleted account's row be destroyed, which would take approved tags with it" do
    person.delete_account!

    expect(person.reload.destroy).to be(false)
    expect(User.exists?(person.id)).to be(true)
  end
end
