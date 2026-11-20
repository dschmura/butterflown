require "rails_helper"

# Archive is a state, so it is a singular resource: POST archives, DELETE
# restores. Replaced the PATCH :archive / :unarchive member actions (#1007).
RSpec.describe "Project Archival", type: :request do
  def owned_project
    owner = create(:membership, :owner)
    Current.workspace = owner.workspace
    sign_in(owner.user)
    create(:project, workspace: owner.workspace, created_by: owner.user)
  end

  describe "unauthenticated access" do
    it "redirects POST /workspaces/:workspace_slug/projects/:slug/archival to sign in" do
      post workspace_project_archival_path(workspace_slug: "any-slug", project_slug: "any-project")
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "authenticated" do
    describe "POST /workspaces/:workspace_slug/projects/:slug/archival" do
      it "archives the project and redirects to the projects index" do
        project = owned_project
        workspace = project.workspace
        post workspace_project_archival_path(workspace, project)
        expect(project.reload).to be_archived
        expect(response).to redirect_to(workspace_projects_path(workspace))
        expect(flash[:notice]).to eq(I18n.t("workspaces.projects.archivals.create.success"))
      end

      it "denies a project member who cannot manage the workspace" do
        project = owned_project
        workspace = project.workspace
        member = add_member(workspace).user
        create(:project_membership, user: member, project: project)
        sign_in(member)
        post workspace_project_archival_path(workspace, project)
        expect(project.reload).not_to be_archived
      end
    end

    describe "DELETE /workspaces/:workspace_slug/projects/:slug/archival" do
      it "restores an archived project and redirects to it" do
        project = owned_project
        workspace = project.workspace
        project.archive!
        delete workspace_project_archival_path(workspace, project)
        expect(project.reload).not_to be_archived
        expect(response).to redirect_to(workspace_project_path(workspace, project))
        expect(flash[:notice]).to eq(I18n.t("workspaces.projects.archivals.destroy.success"))
      end
    end
  end
end
