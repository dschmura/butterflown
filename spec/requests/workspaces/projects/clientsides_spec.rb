require "rails_helper"

RSpec.describe "Project Clientside settings", type: :request do
  def own_project(workspace: nil)
    user = create(:user)
    sign_in(user)
    create(:project, workspace: workspace || user.workspaces.sole, created_by: user)
  end

  it "renders the toggle form" do
    project = own_project
    workspace = project.workspace
    get edit_workspace_project_clientside_path(workspace, project)
    expect(response).to have_http_status(:ok)
  end

  it "links to inviting a client when the creator can manage members" do
    project = own_project
    workspace = project.workspace
    get edit_workspace_project_clientside_path(workspace, project)
    expect(response.body).to include(new_workspace_project_client_invitation_path(workspace, project))
  end

  context "as a creator whose workspace role cannot manage members" do
    it "offers no invite link and names who can invite" do
      project = own_project(workspace: create(:user).workspaces.sole)
      workspace = project.workspace

      get edit_workspace_project_clientside_path(workspace, project)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(new_workspace_project_client_invitation_path(workspace, project))
      expect(response.body).to include(I18n.t("clientside.invitations.new.ask_a_manager"))
    end
  end

  it "enables Clientside" do
    project = own_project
    workspace = project.workspace
    patch workspace_project_clientside_path(workspace, project),
      params: { project: { clientside_enabled: "1" } }
    expect(project.reload.clientside_enabled?).to be(true)
    expect(response).to redirect_to(edit_workspace_project_clientside_path(workspace, project))
    expect(flash[:notice]).to eq(I18n.t("clientside.settings.saved"))
  end

  context "as a project member who is not the creator" do
    it "denies access (redirect, unchanged)" do
      project = own_project
      workspace = project.workspace
      viewer = create(:user)
      create(:membership, :viewer, user: viewer, workspace: workspace)
      create(:project_membership, :viewer, user: viewer, project: project)
      sign_in(viewer)
      patch workspace_project_clientside_path(workspace, project),
        params: { project: { clientside_enabled: "1" } }
      expect(response).to have_http_status(:redirect)
      expect(project.reload.clientside_enabled?).to be(false)
    end
  end
end
