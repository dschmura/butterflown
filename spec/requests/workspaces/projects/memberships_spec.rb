require "rails_helper"

RSpec.describe "Project Memberships", type: :request do
  def create_project_with_creator
    creator = create(:user)
    workspace = create(:workspace)
    create(:membership, :owner, user: creator, workspace: workspace)
    project = create(:project, workspace: workspace, created_by: creator)
    Current.workspace = workspace
    project.project_memberships.find_by!(user: creator)
  end

  def signed_in_creator
    create_project_with_creator.tap { |creator_pm| sign_in(creator_pm.user) }
  end

  def add_workspace_member(workspace)
    create(:membership, user: create(:user), workspace: workspace)
  end

  def add_project_member(project, role: nil)
    member = add_workspace_member(project.workspace)
    create(:project_membership, *[ role ].compact, project: project, user: member.user)
  end

  describe "unauthenticated access" do
    it "redirects GET /workspaces/:slug/projects/:project_slug/memberships to sign in" do
      get workspace_project_memberships_path(workspace_slug: "any-slug", project_slug: "any-project")
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET memberships index" do
    it "lists project members" do
      creator_pm = signed_in_creator
      project = creator_pm.project

      get workspace_project_memberships_path(project.workspace, project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(CGI.escapeHTML(creator_pm.user.full_name))
    end

    # #1150: the button linked to the index it sat on, so clicking it
    # reloaded the list instead of opening the form.
    it "links Add member to the new-membership form" do
      project = signed_in_creator.project
      workspace = project.workspace

      get workspace_project_memberships_path(workspace, project)

      add = Capybara.string(response.body).find_link(I18n.t("workspaces.projects.memberships.index.add_member"))
      expect(add[:href]).to eq(new_workspace_project_membership_path(workspace, project))
    end
  end

  describe "POST create membership" do
    it "adds a workspace member as editor" do
      project = signed_in_creator.project
      workspace = project.workspace
      new_member = add_workspace_member(workspace).user

      expect {
        post workspace_project_memberships_path(workspace, project), params: {
          project_membership: { user_id: new_member.id, role: "editor" }
        }
      }.to change(ProjectMembership, :count).by(1)
      expect(flash[:notice]).to eq(I18n.t("workspaces.projects.memberships.create.success"))
    end

    it "rejects non-workspace members" do
      project = signed_in_creator.project
      outsider = create(:user)

      post workspace_project_memberships_path(project.workspace, project), params: {
        project_membership: { user_id: outsider.id, role: "editor" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH update membership role" do
    it "changes the member's role" do
      project = signed_in_creator.project
      member_pm = add_project_member(project)

      patch workspace_project_membership_path(project.workspace, project, member_pm), params: {
        project_membership: { role: "viewer" }
      }
      expect(member_pm.reload).to be_viewer
      expect(flash[:notice]).to eq(I18n.t("workspaces.projects.memberships.update.role_updated"))
    end
  end

  describe "DELETE membership" do
    it "removes the member" do
      project = signed_in_creator.project
      member_pm = add_project_member(project)

      expect {
        delete workspace_project_membership_path(project.workspace, project, member_pm)
      }.to change(ProjectMembership, :count).by(-1)
      expect(flash[:notice]).to eq(I18n.t("workspaces.projects.memberships.destroy.removed"))
    end

    it "prevents removing the creator" do
      creator_pm = signed_in_creator
      project = creator_pm.project
      add_project_member(project)

      delete workspace_project_membership_path(project.workspace, project, creator_pm)
      expect(response).to have_http_status(:redirect)
      expect(creator_pm.reload).to be_persisted
    end
  end

  describe "PATCH with invalid role" do
    it "handles invalid role gracefully" do
      project = signed_in_creator.project
      workspace = project.workspace
      member_pm = add_project_member(project)

      patch workspace_project_membership_path(workspace, project, member_pm), params: {
        project_membership: { role: "superadmin" }
      }
      expect(response).to redirect_to(workspace_project_memberships_path(workspace, project))
      expect(flash[:alert]).to eq(I18n.t("workspaces.projects.memberships.update.invalid_role"))
    end

    # C7: the invalid-role flash is reserved for an actually-invalid role
    # value; an ArgumentError from anywhere else must surface as itself.
    it "does not mask an unrelated ArgumentError as an invalid role" do
      project = signed_in_creator.project
      member_pm = add_project_member(project)

      allow_any_instance_of(ProjectMembership).to receive(:update!).and_raise(ArgumentError, "boom")
      expect {
        patch workspace_project_membership_path(project.workspace, project, member_pm), params: {
          project_membership: { role: "editor" }
        }
      }.to raise_error(ArgumentError, "boom")
    end
  end

  describe "authorization" do
    describe "editor cannot add members" do
      it "denies creating a membership" do
        project = create_project_with_creator.project
        editor = add_project_member(project)
        target = add_workspace_member(project.workspace).user
        sign_in(editor.user)

        expect {
          post workspace_project_memberships_path(project.workspace, project), params: {
            project_membership: { user_id: target.id, role: "viewer" }
          }
        }.not_to change(ProjectMembership, :count)
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "editor cannot change roles" do
      it "denies updating a membership role" do
        project = create_project_with_creator.project
        editor = add_project_member(project)
        target = add_workspace_member(project.workspace).user
        target_pm = create(:project_membership, :viewer, project: project, user: target)
        sign_in(editor.user)

        patch workspace_project_membership_path(project.workspace, project, target_pm), params: {
          project_membership: { role: "editor" }
        }
        expect(target_pm.reload).to be_viewer
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "editor cannot remove members" do
      it "denies deleting a membership" do
        project = create_project_with_creator.project
        editor = add_project_member(project)
        target = add_workspace_member(project.workspace).user
        target_pm = create(:project_membership, :viewer, project: project, user: target)
        sign_in(editor.user)

        expect {
          delete workspace_project_membership_path(project.workspace, project, target_pm)
        }.not_to change(ProjectMembership, :count)
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "viewer cannot add members" do
      it "denies creating a membership" do
        project = create_project_with_creator.project
        target = add_workspace_member(project.workspace).user
        viewer = add_project_member(project, role: :viewer)
        sign_in(viewer.user)

        expect {
          post workspace_project_memberships_path(project.workspace, project), params: {
            project_membership: { user_id: target.id, role: "editor" }
          }
        }.not_to change(ProjectMembership, :count)
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "non-project-member cannot access memberships" do
      it "denies listing memberships" do
        project = create_project_with_creator.project
        outsider = add_workspace_member(project.workspace).user
        sign_in(outsider)

        get workspace_project_memberships_path(project.workspace, project)
        expect(response).to have_http_status(:redirect)
      end

      it "denies adding a member with arbitrary user_id" do
        project = create_project_with_creator.project
        target = add_workspace_member(project.workspace).user
        outsider = add_workspace_member(project.workspace).user
        sign_in(outsider)

        expect {
          post workspace_project_memberships_path(project.workspace, project), params: {
            project_membership: { user_id: target.id, role: "editor" }
          }
        }.not_to change(ProjectMembership, :count)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # #686: pinning is an idempotent end-state resource; the old toggle
  # un-pinned on a retried or double-submitted request.
  describe "pin resource" do
    it "POST pins own membership, idempotently (two POSTs = pinned once)" do
      creator_pm = signed_in_creator
      project = creator_pm.project

      post workspace_project_pin_path(project.workspace, project)
      expect(creator_pm.reload).to be_pinned
      expect(flash[:notice]).to eq(I18n.t("workspaces.projects.pins.toggled"))

      post workspace_project_pin_path(project.workspace, project)
      expect(creator_pm.reload).to be_pinned
    end

    it "DELETE unpins, idempotently" do
      creator_pm = signed_in_creator
      project = creator_pm.project
      creator_pm.update!(pinned: true)

      delete workspace_project_pin_path(project.workspace, project)
      expect(creator_pm.reload).not_to be_pinned

      delete workspace_project_pin_path(project.workspace, project)
      expect(creator_pm.reload).not_to be_pinned
    end
  end
end
