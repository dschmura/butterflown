require "rails_helper"

RSpec.describe "Project tool tabs", type: :request do
  describe "unauthenticated access" do
    it "redirects GET /workspaces/:slug/projects/:project_slug to sign in" do
      get workspace_project_path(workspace_slug: "any-slug", slug: "any-project")
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "authenticated" do
    def sign_in_owner_with_project
      workspace = create(:workspace)
      owner = sign_in_as_owner_of(workspace)
      project = create(:project, workspace: workspace, created_by: owner)
      [ workspace, project ]
    end

    it "renders a Docs tab linking to the project's resources" do
      workspace, project = sign_in_owner_with_project
      get workspace_project_path(workspace, project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(workspace_project_resources_path(workspace, project))
      expect(response.body).to include("Docs &amp; Files")
    end

    it "omits a tool's tab when it is disabled" do
      workspace, project = sign_in_owner_with_project
      project.update!(enabled_tools: [])
      get workspace_project_path(workspace, project)
      expect(response.body).not_to include(workspace_project_resources_path(workspace, project))
    end
  end
end
