require "rails_helper"

RSpec.describe "Workspace Settings", type: :request do
  describe "unauthenticated access" do
    it "redirects GET /workspaces/:slug/settings/edit to sign in" do
      get edit_workspace_settings_path(workspace_slug: "any-slug")
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "authenticated" do
    def sign_in_owner_of_workspace
      workspace = create(:workspace)
      owner = create(:user)
      create(:membership, :owner, user: owner, workspace: workspace)
      sign_in(owner)
      workspace
    end

    describe "GET /workspaces/:workspace_slug/settings/edit" do
      it "renders the settings form" do
        workspace = sign_in_owner_of_workspace
        get edit_workspace_settings_path(workspace)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "PATCH /workspaces/:workspace_slug/settings" do
      it "updates max_members" do
        workspace = sign_in_owner_of_workspace
        patch workspace_settings_path(workspace), params: { workspace: { max_members: 10 } }
        expect(workspace.reload.max_members).to eq(10)
      end

      it "updates max_projects" do
        workspace = sign_in_owner_of_workspace
        patch workspace_settings_path(workspace), params: { workspace: { max_projects: 5 } }
        expect(workspace.reload.max_projects).to eq(5)
      end

      it "redirects with success message" do
        workspace = sign_in_owner_of_workspace
        patch workspace_settings_path(workspace), params: { workspace: { max_members: 10 } }
        expect(response).to redirect_to(edit_workspace_settings_path(workspace))
        expect(flash[:notice]).to eq(I18n.t("workspaces.settings.update.success"))
      end
    end

    describe "PATCH with invalid params" do
      it "returns unprocessable entity for zero max_members" do
        workspace = sign_in_owner_of_workspace
        patch workspace_settings_path(workspace), params: { workspace: { max_members: 0 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "authorization" do
      it "rejects non-owner/admin access" do
        workspace = sign_in_owner_of_workspace
        viewer_role = Role.find_or_create_by!(slug: "viewer", workspace_id: nil) { |r| r.name = "Viewer" }
        viewer = create(:user)
        create(:membership, user: viewer, workspace: workspace, role: viewer_role)
        sign_in(viewer)
        get edit_workspace_settings_path(workspace)
        expect(response).to redirect_to(workspace_path(workspace))
      end
    end
  end
end
