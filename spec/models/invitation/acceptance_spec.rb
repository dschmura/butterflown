require "rails_helper"

# Invitation::Acceptance's examples. A concern trait is not instantiated, so its
# examples describe the model; this file is scoped by directory to the trait.
RSpec.describe Invitation, type: :model do
  def owned_project
    workspace = create(:workspace)
    owner = create(:user)
    create(:membership, :owner, user: owner, workspace: workspace)
    create(:project, workspace: workspace, created_by: owner)
  end

  def invite_to_project(project, inviter:, email:, project_role: "editor")
    viewer_role = Role.system_default!("viewer")
    project.invitations.create!(
      email: email,
      role: viewer_role,
      project_role: project_role,
      invited_by: inviter,
      expires_at: 7.days.from_now
    )
  end

  describe "#accept! raise behavior" do
    it "raises Invitation::NotAcceptable when invitation is already accepted" do
      invitation = create(:invitation, :accepted)
      user = create(:user)
      expect {
        invitation.accept!(user)
      }.to raise_error(Invitation::NotAcceptable, /no longer acceptable/i)
    end

    it "raises Invitation::NotAcceptable when invitation is expired" do
      invitation = create(:invitation, :expired)
      user = create(:user)
      expect {
        invitation.accept!(user)
      }.to raise_error(Invitation::NotAcceptable, /no longer acceptable/i)
    end

    it "raises Invitation::NotAcceptable when invitation is declined" do
      invitation = create(:invitation, :declined)
      user = create(:user)
      expect {
        invitation.accept!(user)
      }.to raise_error(Invitation::NotAcceptable, /no longer acceptable/i)
    end

    it "does NOT raise NotAcceptable on a valid pending invitation" do
      invitation = create(:invitation)
      user = create(:user)
      expect {
        invitation.accept!(user)
      }.not_to raise_error
    end

    # G (SEC-1 follow-up): the invitation flow — the most common grant path —
    # logged membership.created with empty metadata and only the accepting
    # invitee as actor. The granter and granted role now ride as metadata
    # (the actor stays the invitee: they performed the accept).
    it "audits the granted membership with role and granter" do
      invitation = create(:invitation)
      user = create(:user)
      invitation.accept!(user)

      membership = invitation.invitable.memberships.find_by(user: user)
      entry = ActivityLog.where(action: "membership.created", trackable: membership).last
      expect(entry).to be_present
      expect(entry.metadata["role"]).to eq(invitation.role.slug)
      expect(entry.metadata["granted_by"]).to eq(invitation.invited_by_id)
    end

    it "raises Invitation::NotAcceptable when the target workspace is suspended (workspace invitation)" do
      workspace = create(:workspace)
      invitation = create(:invitation, invitable: workspace)
      workspace.suspend!
      # Force user creation outside the expect block — onboarding callbacks
      # create their own membership, which would confound the count.
      user = create(:user)

      expect {
        invitation.accept!(user)
      }.to raise_error(Invitation::NotAcceptable, /no longer acceptable/i)
        .and change(Membership, :count).by(0)
    end

    it "raises Invitation::NotAcceptable when the target workspace is suspended (project invitation)" do
      workspace = create(:workspace)
      owner = create(:user)
      create(:membership, :owner, user: owner, workspace: workspace)
      project = create(:project, workspace: workspace, created_by: owner)
      invitation = invite_to_project(project, inviter: owner, email: "project-invitee@example.com")
      workspace.suspend!
      # Force user creation outside the expect block — onboarding callbacks
      # create their own membership, which would confound the count.
      user = create(:user)

      expect {
        invitation.accept!(user)
      }.to raise_error(Invitation::NotAcceptable, /no longer acceptable/i)
        .and change(Membership, :count).by(0)
    end
  end

  describe "#accept!" do
    it "creates a membership" do
      invitation = create(:invitation, invitable: create(:workspace))
      user = create(:user)
      expect { invitation.accept!(user) }.to change(Membership, :count).by(1)
    end

    it "prevents double-accept" do
      invitation = create(:invitation, invitable: create(:workspace))
      user = create(:user)
      invitation.accept!(user)
      expect { invitation.accept!(create(:user)) }.to raise_error(Invitation::NotAcceptable)
    end

    it "sets accepted status" do
      invitation = create(:invitation, invitable: create(:workspace))
      user = create(:user)
      invitation.accept!(user)
      expect(invitation.reload.status).to eq("accepted")
      expect(invitation.accepted_by).to eq(user)
      expect(invitation.accepted_at).to be_present
    end

    it "assigns the invitation's role to the membership" do
      workspace = create(:workspace)
      invitation = create(:invitation, invitable: workspace)
      user = create(:user)
      invitation.accept!(user)
      membership = workspace.memberships.find_by(user: user)
      expect(membership.role).to eq(invitation.role)
    end

    it "marks the invitee onboarded" do
      invitation = create(:invitation, invitable: create(:workspace))
      user = create(:user)
      expect { invitation.accept!(user) }.to change { user.reload.onboarded? }.from(false).to(true)
    end

    it "raises if user is already a member" do
      workspace = create(:workspace)
      invitation = create(:invitation, invitable: workspace)
      user = create(:user)
      create(:membership, user: user, workspace: workspace)
      expect { invitation.accept!(user) }.to raise_error(Workspace::AlreadyMember)
    end
  end

  describe "#accept! reactivates discarded workspace membership" do
    it "reactivates discarded membership on workspace re-invite" do
      workspace = create(:workspace)
      invitation = create(:invitation, invitable: workspace)
      user = create(:user)
      old_membership = create(:membership, user: user, workspace: workspace)
      other_owner = create(:user)
      create(:membership, :owner, user: other_owner, workspace: workspace)
      old_membership.deactivate!

      invitation.accept!(user)
      expect(old_membership.reload).not_to be_discarded
    end
  end

  # Regression: capacity is enforced through the invitation acceptance path.
  # Membership-level capacity is also tested in spec/models/membership_spec.rb,
  # but the accept! flow goes through Invitation#accept_workspace_invitation!
  # which acquires workspace.lock! BEFORE checking the count (line 111 vs 118).
  # This test locks in that the lock-then-check sequence prevents over-capacity
  # acceptances, even on engines (e.g., PostgreSQL) where row-level locks are
  # the only serialization mechanism. SQLite's BEGIN IMMEDIATE provides
  # additional database-wide write serialization, but this test asserts the
  # business rule independent of engine.
  describe "#accept! capacity enforcement (regression)" do
    it "rejects acceptance when workspace is at max_members" do
      workspace = create(:workspace, max_members: 2)
      create(:membership, :owner, workspace: workspace)
      create(:membership, workspace: workspace)
      invitation = create(:invitation, invitable: workspace)
      user = create(:user)

      expect { invitation.accept!(user) }
        .to raise_error(Workspace::AtCapacity)

      expect(workspace.memberships.kept.count).to eq(2)
      expect(invitation.reload).to be_pending
    end

    it "rejects project-invitation acceptance when workspace is at capacity" do
      workspace = create(:workspace, max_members: 2)
      owner_membership = create(:membership, :owner, workspace: workspace)
      create(:membership, workspace: workspace)
      # Reuse the owner as the project's created_by to avoid the project factory's
      # after_create membership backfill (which would push the workspace over cap
      # before our invitation acceptance even runs — see spec/factories/projects.rb).
      project = create(:project, workspace: workspace, created_by: owner_membership.user)
      invitation = create(:invitation, invitable: project, project_role: "editor")
      user = create(:user)

      # Same typed error as the workspace path: capacity is enforced inside
      # Workspace#admit for every admission flow.
      expect { invitation.accept!(user) }
        .to raise_error(Workspace::AtCapacity)

      expect(workspace.memberships.kept.count).to eq(2)
      expect(invitation.reload).to be_pending
    end
  end

  describe "#accept! for project invitation" do
    it "marks the invitee onboarded" do
      project = owned_project
      invitation = invite_to_project(project, inviter: project.created_by, email: "project-invitee@example.com")
      invitee = create(:user, email_address: "project-invitee@example.com")
      expect { invitation.accept!(invitee) }.to change { invitee.reload.onboarded? }.from(false).to(true)
    end

    it "creates workspace membership and project membership" do
      project = owned_project
      workspace = project.workspace
      invitation = invite_to_project(project, inviter: project.created_by, email: "project-invitee@example.com")
      invitee = create(:user, email_address: "project-invitee@example.com")
      invitation.accept!(invitee)
      expect(workspace.memberships.kept.exists?(user: invitee)).to be true
      expect(project.project_memberships.exists?(user: invitee)).to be true
    end

    # Regression: this path once hand-rolled the membership grant and dropped
    # granted_by, so the most common project-invite grant audited no granter
    # (granted_by is non-persisted by design — the audit row is where the
    # provenance lives, so it is also where the regression is pinned).
    it "audits the granted workspace membership with role and granter" do
      project = owned_project
      workspace = project.workspace
      owner = project.created_by
      invitation = invite_to_project(project, inviter: owner, email: "project-invitee@example.com")
      invitee = create(:user, email_address: "project-invitee@example.com")
      invitation.accept!(invitee)

      membership = workspace.memberships.find_by!(user: invitee)
      entry = ActivityLog.where(action: "membership.created", trackable: membership).last
      expect(entry).to be_present
      expect(entry.metadata["role"]).to eq(invitation.role.slug)
      expect(entry.metadata["granted_by"]).to eq(owner.id)
    end

    it "assigns the correct project role" do
      project = owned_project
      invitee = create(:user, email_address: "project-invitee2@example.com")
      invitation2 = invite_to_project(project, inviter: project.created_by, email: "project-invitee2@example.com",
                                               project_role: "viewer")
      invitation2.accept!(invitee)
      pm = project.project_memberships.find_by(user: invitee)
      expect(pm).to be_viewer
    end

    it "raises NotAcceptable for a discarded project" do
      project = owned_project
      project.discard!
      invitee = create(:user)
      invitation = invite_to_project(project, inviter: project.created_by, email: "project-invitee@example.com")
      expect { invitation.accept!(invitee) }.to raise_error(Invitation::NotAcceptable)
    end
  end

  describe "#accept! when user is already a project member" do
    it "raises when user is already a project member" do
      project = owned_project
      workspace = project.workspace
      existing_user = create(:user, email_address: "already-member@example.com")
      create(:membership, user: existing_user, workspace: workspace)
      create(:project_membership, project: project, user: existing_user)
      invitation = invite_to_project(project, inviter: project.created_by, email: "already-member@example.com")

      expect { invitation.accept!(existing_user) }.to raise_error(ActiveRecord::RecordInvalid) { |e|
        expect(e.record.errors.details[:base]).to include(error: :already_project_member)
      }
    end
  end

  describe "#accept! reactivates discarded workspace membership for project invitation" do
    it "reactivates the discarded membership" do
      project = owned_project
      workspace = project.workspace
      user = create(:user)
      ws_membership = create(:membership, user: user, workspace: workspace)
      other_owner = create(:membership, :owner, workspace: workspace)
      ws_membership.deactivate!

      invitation = invite_to_project(project, inviter: project.created_by, email: user.email_address)

      invitation.accept!(user)
      expect(ws_membership.reload).not_to be_discarded
      expect(project.project_memberships.exists?(user: user)).to be true
    end
  end

  # Shared consumption core used by both the session-based (Signupable) and
  # column-based (Authentication#claim_pending_invitation!) acceptance paths.
  describe ".consume!" do
    it "accepts the matching invitation and returns it" do
      workspace = create(:workspace)
      invitation = create(:invitation, invitable: workspace)
      user = create(:user)

      result = Invitation.consume!(token: invitation.token, user: user)

      expect(result).to eq(invitation)
      expect(invitation.reload).to be_accepted
      expect(workspace.memberships.kept.exists?(user: user)).to be true
    end

    it "returns nil when the token is blank" do
      user = create(:user)
      expect(Invitation.consume!(token: nil, user: user)).to be_nil
      expect(Invitation.consume!(token: "", user: user)).to be_nil
    end

    it "returns nil when no invitation matches the token" do
      user = create(:user)
      expect(Invitation.consume!(token: "does-not-exist", user: user)).to be_nil
    end

    it "raises Invitation::NotAcceptable when the invitation is no longer acceptable" do
      invitation = create(:invitation, :accepted, invitable: create(:workspace))
      user = create(:user)

      expect {
        Invitation.consume!(token: invitation.token, user: user)
      }.to raise_error(Invitation::NotAcceptable)
    end

    context "with expected_email (email-match guard)" do
      it "accepts when the proven email matches the invitation email (case-insensitive)" do
        workspace = create(:workspace)
        invitation = create(:invitation, invitable: workspace, email: "Invitee@Example.com")
        matching = create(:user, email_address: "invitee@example.com")

        result = Invitation.consume!(token: invitation.token, user: matching, expected_email: matching.email_address)

        expect(result).to eq(invitation)
        expect(invitation.reload).to be_accepted
      end

      it "raises EmailMismatch when the proven email differs from the invitation email" do
        workspace = create(:workspace)
        invitation = create(:invitation, invitable: workspace, email: "invitee@example.com")
        other = create(:user, email_address: "someone-else@example.com")

        expect {
          Invitation.consume!(token: invitation.token, user: other, expected_email: other.email_address)
        }.to raise_error(Invitation::EmailMismatch)

        expect(invitation.reload).to be_pending
        expect(workspace.memberships.kept.exists?(user: other)).to be false
      end

      it "is a kind of NotAcceptable so existing boundary rescues still catch it" do
        expect(Invitation::EmailMismatch.ancestors).to include(Invitation::NotAcceptable)
      end

      it "consumes a magic-link invitation (nil email) regardless of expected_email" do
        invitation = create(:invitation, :magic_link, invitable: create(:workspace))
        anyone = create(:user, email_address: "anyone@example.com")

        result = Invitation.consume!(token: invitation.token, user: anyone, expected_email: anyone.email_address)

        expect(result).to eq(invitation)
        expect(invitation.reload).to be_accepted
      end

      it "skips the guard when expected_email is not provided (direct callers)" do
        invitation = create(:invitation, invitable: create(:workspace), email: "invitee@example.com")
        user = create(:user)
        # user's email differs, but no expected_email is passed → no guard
        result = Invitation.consume!(token: invitation.token, user: user)

        expect(result).to eq(invitation)
      end
    end
  end

  describe "client invitations" do
    def clientside_project
      create(:project, clientside_enabled: true)
    end

    it "is a client invite when it is flagged as one" do
      Role.system_default!("owner")
      project = clientside_project
      inv = build(:invitation, :client, invitable: project)
      expect(inv.client_invite?).to be(true)
      expect(inv).to be_valid
    end

    it "is not a client invite just because a company name is set" do
      expect(build(:invitation, company_name: "BigCo").client_invite?).to be(false)
    end

    it "allows a nil role only for client invites" do
      Role.system_default!("owner")
      member = build(:invitation, role: nil, company_name: nil)
      expect(member).not_to be_valid
      expect(member.errors[:role]).to be_present
    end

    it ".invite_client! creates the invite and enqueues the client mailer" do
      Role.system_default!("owner")
      project = clientside_project
      inviter = create(:user)
      expect {
        Invitation.invite_client!(project: project, email: "dana@bigco.com",
                                  company_name: "BigCo", invited_by: inviter)
      }.to have_enqueued_mail(InvitationMailer, :invite_client)
      inv = Invitation.last
      expect(inv.client).to be(true)
      expect(inv.role).to be_nil
      expect(inv.invitable).to eq(project)
    end

    it "accept! creates a ClientAccess and stamps onboarded_at" do
      Role.system_default!("owner")
      project = clientside_project
      inviter = create(:user)
      inv = Invitation.invite_client!(project: project, email: "dana@bigco.com",
                                      company_name: "BigCo", invited_by: inviter)
      client = create(:user, :with_zero_workspaces, email_address: "dana@bigco.com")
      expect { inv.accept!(client) }.to change { project.client_accesses.kept.count }.by(1)
      expect(project.client?(client)).to be(true)
      expect(client.reload.onboarded?).to be(true)
      expect(inv.reload).to be_accepted
    end

    it "consume! still guards against a mismatched email (bearer protection)" do
      Role.system_default!("owner")
      project = clientside_project
      inviter = create(:user)
      inv = Invitation.invite_client!(project: project, email: "dana@bigco.com",
                                      company_name: "BigCo", invited_by: inviter)
      other = create(:user, :with_zero_workspaces, email_address: "evil@example.com")
      expect { Invitation.consume!(token: inv.token, user: other, expected_email: other.email_address) }
        .to raise_error(Invitation::EmailMismatch)
    end

    it "accept! raises NotAcceptable when Clientside is disabled (undiscard bypass)" do
      Role.system_default!("owner")
      project = clientside_project
      inviter = create(:user)
      inv = Invitation.invite_client!(project: project, email: "dana@bigco.com",
                                      company_name: "BigCo", invited_by: inviter)
      client = create(:user, :with_zero_workspaces, email_address: "dana@bigco.com")
      project.client_accesses.create!(user: client, company_name: "BigCo").discard!
      project.update!(clientside_enabled: false)

      expect { inv.accept!(client) }.to raise_error(Invitation::NotAcceptable, /clientside is disabled/i)
    end

    it "accept! still succeeds when Clientside is enabled (happy path)" do
      Role.system_default!("owner")
      project = clientside_project
      inviter = create(:user)
      inv = Invitation.invite_client!(project: project, email: "happy@bigco.com",
                                      company_name: "BigCo", invited_by: inviter)
      client = create(:user, :with_zero_workspaces, email_address: "happy@bigco.com")
      expect { inv.accept!(client) }.to change { project.client_accesses.kept.count }.by(1)
      expect(inv.reload).to be_accepted
    end

    it "is invalid when invitable is a Workspace, not a Project" do
      Role.system_default!("owner")
      inv = build(:invitation, :client, invitable: create(:workspace))
      expect(inv).not_to be_valid
      expect(inv.errors[:base]).to be_present
    end

    it "accept! for a client invitation to a discarded project raises NotAcceptable and creates no ClientAccess" do
      Role.system_default!("owner")
      project = clientside_project
      inviter = create(:user)
      inv = Invitation.invite_client!(project: project, email: "dana@bigco.com",
                                      company_name: "BigCo", invited_by: inviter)
      client = create(:user, :with_zero_workspaces, email_address: "dana@bigco.com")
      project.discard!

      expect { inv.accept!(client) }.to raise_error(Invitation::NotAcceptable)
      expect(ClientAccess.where(user: client, project: project)).to be_empty
    end

    # Closes the admission matrix for the CLIENT (project-invitable) vector: the
    # single accept! choke-point guard (unless resolved_workspace&.admittable?)
    # resolves the workspace THROUGH the project, so a new client invitation into
    # an archived (or deleted) workspace is blocked — new admission requires an
    # active workspace, even though archived KEEPS existing client access.
    it "accept! for a client invitation whose workspace is archived raises NotAcceptable and creates no ClientAccess" do
      Role.system_default!("owner")
      project = clientside_project
      inviter = create(:user)
      inv = Invitation.invite_client!(project: project, email: "arch@bigco.com",
                                      company_name: "BigCo", invited_by: inviter)
      client = create(:user, :with_zero_workspaces, email_address: "arch@bigco.com")
      project.workspace.archive!

      expect { inv.accept!(client) }.to raise_error(Invitation::NotAcceptable)
      expect(ClientAccess.where(user: client, project: project)).to be_empty
    end
  end

  # Reshape 1 reconciliation: under :shared posture, User#onboard_workspace
  # pre-creates a Member membership at signup. The invitation flow must then
  # adopt the invitation's role rather than treating the existing membership
  # as a duplicate-accept error. Solo-default (:personal) semantics unchanged.
  describe "#accept! reconciles role under :shared posture" do
    def shared_posture_cast
      shared_workspace = create(:workspace, slug: "acme", personal: false)
      admin_role = Role.system_default!("admin")
      member_role = Role.system_default!("member")
      [ shared_workspace, admin_role, member_role ]
    end

    before do
      allow(Rails.configuration.x.tenancy).to receive(:onboarding).and_return(:shared)
      allow(Rails.configuration.x.tenancy).to receive(:shared_workspace_slug).and_return("acme")
    end

    it "promotes the placeholder Member to the invitation's Admin role" do
      shared_workspace, admin_role, member_role = shared_posture_cast
      invitee = create(:user, email_address: "newbie@example.com")
      # Callback created a Member membership; verify state before reconciliation.
      placeholder = shared_workspace.memberships.find_by!(user: invitee)
      expect(placeholder.role).to eq(member_role)

      invitation = create(:invitation,
                          invitable: shared_workspace,
                          role: admin_role,
                          email: "newbie@example.com",
                          invited_by: create(:user))

      expect {
        invitation.accept!(invitee)
      }.not_to raise_error

      expect(shared_workspace.memberships.where(user: invitee).count).to eq(1)
      expect(placeholder.reload.role).to eq(admin_role)
    end

    it "no-ops when the invitation's role matches the placeholder Member role" do
      shared_workspace, _admin_role, member_role = shared_posture_cast
      invitee = create(:user, email_address: "samerole@example.com")
      invitation = create(:invitation,
                          invitable: shared_workspace,
                          role: member_role,
                          email: "samerole@example.com",
                          invited_by: create(:user))

      expect { invitation.accept!(invitee) }.not_to raise_error
      expect(shared_workspace.memberships.where(user: invitee).count).to eq(1)
    end
  end
end
