require "rails_helper"

RSpec.describe "Onboarding · project step", type: :request do
  before { allow(TenancyConfig).to receive(:onboarding).and_return(:none) }

  def signed_in_owner_with_workspace
    user = create(:user, :with_zero_workspaces)
    workspace = create(:workspace)
    create(:membership, :owner, user: user, workspace: workspace)
    sign_in(user)
    [ user, workspace ]
  end

  it "renders the new-project form" do
    signed_in_owner_with_workspace
    get new_onboarding_project_path
    expect(response).to have_http_status(:ok)
  end

  it "creates the project and advances to the team step" do
    user, workspace = signed_in_owner_with_workspace
    expect {
      post onboarding_project_path, params: { project: { name: "Acme Website", description: "Marketing site" } }
    }.to change(workspace.projects.kept, :count).by(1)

    project = workspace.projects.kept.first
    expect(project.name).to eq("Acme Website")
    expect(project.description).to eq("Marketing site")
    expect(project.project_memberships.find_by(user: user)&.role).to eq("creator")
    expect(response).to redirect_to(new_onboarding_team_path)
    expect(flash[:notice]).to eq(I18n.t("onboarding.projects.create.success"))
  end

  it "re-renders on a blank name" do
    _user, workspace = signed_in_owner_with_workspace
    expect {
      post onboarding_project_path, params: { project: { name: "" } }
    }.not_to change(workspace.projects.kept, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "redirects back to the account step if no workspace exists yet" do
    signed_in_owner_with_workspace
    other = create(:user, :with_zero_workspaces)
    sign_in(other)
    get new_onboarding_project_path
    expect(response).to redirect_to(new_onboarding_workspace_path)
  end

  it "does not create a project and redirects when the workspace is suspended" do
    _user, workspace = signed_in_owner_with_workspace
    workspace.suspend!

    expect {
      post onboarding_project_path, params: { project: { name: "Acme Website", description: "Marketing site" } }
    }.not_to change(Project, :count)

    expect(response).to redirect_to(workspaces_path)
    expect(flash[:alert]).to eq(I18n.t("workspaces.locked_notice"))
  end
end
