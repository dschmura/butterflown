require "rails_helper"

RSpec.describe Membership, type: :model do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:onlooker) { create(:membership, workspace: community).user }
  let(:membership) { create(:membership, workspace: community) }
  let(:person) { membership.user }

  def remove_for_cause(reason: "Repeated harassment after two warnings")
    membership.remove_for_cause!(by: admin, reason: reason)
  end

  describe "#remove_for_cause!" do
    it "ends the membership and records the cause" do
      remove_for_cause

      expect(membership.reload).to have_attributes(discarded?: true, departure: "removed_for_cause")
    end

    it "puts the reason in the audit log, where only admins see it" do
      remove_for_cause

      entry = ActivityLog.find_by!(trackable: membership, action: "membership.removed_for_cause")
      expect(entry).to have_attributes(visibility: "admin", metadata: include("reason" => "Repeated harassment after two warnings"))
    end

    it "keeps the reason and the cause out of what the community's feed shows" do
      remove_for_cause

      community_rows = ActivityLog.where(trackable: membership).where.not(visibility: "admin")
      expect(community_rows.map(&:metadata).to_s).not_to include("harassment", "removed_for_cause")
    end

    it "requires a reason, and changes nothing without one" do
      expect { remove_for_cause(reason: " ") }.to raise_error(ActiveRecord::RecordInvalid, /reason/i)
      expect(membership.reload).to have_attributes(kept?: true, departure: nil)
    end

    it "applies to someone who already left, so leaving first can't dodge it" do
      shared = create(:memory, workspace: community, author: person, visibility: "community")
      invitation = create(:invitation, invitable: community, email: person.email_address, invited_by: admin)
      membership.leave!

      remove_for_cause

      expect(membership.reload).to have_attributes(discarded?: true, departure: "removed_for_cause")
      expect(ActivityLog.where(trackable: membership, action: "membership.removed_for_cause")).to exist
      expect(Memory.visible_to(onlooker)).not_to include(shared)
      expect(invitation.reload.status).to eq("revoked")
    end

    it "keeps someone who asked to delete their account from cancelling their way back in" do
      person.request_deletion!
      membership.reload
      remove_for_cause

      person.cancel_deletion!

      expect(membership.reload).to have_attributes(discarded?: true, departure: "removed_for_cause")
    end

    it "changes nothing the second time" do
      remove_for_cause

      expect { remove_for_cause(reason: "Something else") }
        .not_to(change { ActivityLog.where(trackable: membership, action: "membership.removed_for_cause").count })
    end
  end

  describe "invitations already sent" do
    it "revokes the pending ones addressed to them, here and in this community's projects" do
      to_community = create(:invitation, invitable: community, email: person.email_address, invited_by: admin)
      to_project = create(:invitation, invitable: create(:project, workspace: community), email: person.email_address, invited_by: admin)

      remove_for_cause

      expect([ to_community, to_project ].map { |invitation| invitation.reload.status }).to all(eq("revoked"))
    end

    it "leaves invitations to anyone else, or to another community, alone" do
      someone_else = create(:invitation, invitable: community, invited_by: admin)
      elsewhere = create(:invitation, invitable: create(:workspace), email: person.email_address)

      remove_for_cause

      expect([ someone_else, elsewhere ].map { |invitation| invitation.reload.status }).to all(eq("pending"))
    end
  end

  describe "coming back" do
    before { remove_for_cause }

    it "refuses a self-join through an open link" do
      expect { community.admit(person, role: Role.system_default!("member"), self_join: true) }
        .to raise_error(ActiveRecord::RecordInvalid, /removed for cause/i)
      expect(membership.reload).to have_attributes(discarded?: true, departure: "removed_for_cause")
    end

    it "refuses an invitation from someone here who isn't an admin, such as a project editor" do
      expect { community.admit(person, role: Role.system_default!("member"), granted_by: onlooker, on_existing: :adopt) }
        .to raise_error(ActiveRecord::RecordInvalid, /removed for cause/i)
    end

    it "refuses an invitation from an admin of another community" do
      outsider = create(:membership, :admin, workspace: create(:workspace)).user

      expect { community.admit(person, role: Role.system_default!("member"), granted_by: outsider) }
        .to raise_error(ActiveRecord::RecordInvalid, /removed for cause/i)
    end

    it "lets an admin's invitation bring them back, clearing the cause" do
      community.admit(person, role: Role.system_default!("member"), granted_by: admin)

      expect(membership.reload).to have_attributes(kept?: true, departure: nil)
    end
  end

  describe "their memories" do
    let!(:shared) { create(:memory, workspace: community, author: person, visibility: "community") }
    let!(:anonymous) { create(:memory, workspace: community, author: person, visibility: "community", anonymous: true) }
    let!(:named) do
      create(:memory, workspace: community, author: person, visibility: "specific_people").tap do |memory|
        memory.accesses.create!(user: onlooker)
      end
    end
    let!(:private_memory) { create(:memory, workspace: community, author: person, visibility: "only_me") }
    let!(:someone_elses) { create(:memory, workspace: community, author: onlooker, visibility: "community") }

    it "hides the ones with their name on from the community, admins included" do
      remove_for_cause

      [ onlooker, admin ].each do |viewer|
        expect(Memory.visible_to(viewer)).to contain_exactly(anonymous, someone_elses)
      end
    end

    it "keeps an anonymous one where it was, or its vanishing would point at its author" do
      expect { remove_for_cause }.not_to(change { Memory.visible_to(onlooker).include?(anonymous) }.from(true))
    end

    it "shows them again once an admin brings the person back" do
      remove_for_cause
      community.admit(person, role: Role.system_default!("member"), granted_by: admin)

      expect(Memory.visible_to(onlooker)).to contain_exactly(shared, anonymous, named, someone_elses)
    end

    it "leaves their memories in another community alone" do
      elsewhere = create(:workspace)
      create(:membership, workspace: elsewhere, user: person)
      reader = create(:membership, workspace: elsewhere).user
      theirs_elsewhere = create(:memory, workspace: elsewhere, author: person, visibility: "community")

      remove_for_cause

      expect(Memory.visible_to(reader)).to contain_exactly(theirs_elsewhere)
    end

    it "keeps them on the person's exit page, to download, for 90 days" do
      remove_for_cause

      expect(Memory.on_exit_page_of(person)).to contain_exactly(shared, anonymous, named, private_memory)
    end

    it "purges the private one after 90 days and holds the shared ones" do
      remove_for_cause

      Memory.purge_left_behind(now: 90.days.from_now + 1.minute)

      expect(Memory.where(id: [ shared, anonymous, named, private_memory ]))
        .to contain_exactly(shared, anonymous, named)
    end
  end
end
