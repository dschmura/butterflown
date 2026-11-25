require "rails_helper"

RSpec.describe "Client invitations (team side)", type: :request do
  def team_project
    user = create(:user)
    sign_in(user)
    create(:project, workspace: user.workspaces.sole, created_by: user, clientside_enabled: true)
  end

  it "renders the invite form when Clientside is on" do
    project = team_project
    workspace = project.workspace
    get new_workspace_project_client_invitation_path(workspace, project)
    expect(response).to have_http_status(:ok)
  end

  it "redirects to settings when Clientside is off" do
    project = team_project
    workspace = project.workspace
    project.update!(clientside_enabled: false)
    get new_workspace_project_client_invitation_path(workspace, project)
    expect(response).to redirect_to(edit_workspace_project_clientside_path(workspace, project))
    expect(flash[:alert]).to eq(I18n.t("clientside.invitations.disabled"))
  end

  it "sends a client invitation" do
    project = team_project
    workspace = project.workspace
    expect {
      post workspace_project_client_invitations_path(workspace, project),
        params: { client_invitation: { email: "dana@bigco.com" } }
    }.to change { project.invitations.where(client: true).count }.by(1)
    expect(response).to redirect_to(edit_workspace_project_clientside_path(workspace, project))
  end

  it "re-renders on an invalid email" do
    project = team_project
    workspace = project.workspace
    post workspace_project_client_invitations_path(workspace, project),
      params: { client_invitation: { email: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(flash[:alert]).to eq(I18n.t("clientside.invitations.invalid"))
  end

  it "returns 422 and does not create a second invitation when email already has a pending invite" do
    project = team_project
    workspace = project.workspace
    post workspace_project_client_invitations_path(workspace, project),
      params: { client_invitation: { email: "dana@bigco.com" } }
    expect(response).to redirect_to(edit_workspace_project_clientside_path(workspace, project))

    expect {
      post workspace_project_client_invitations_path(workspace, project),
        params: { client_invitation: { email: "dana@bigco.com" } }
    }.not_to change { project.invitations.where(client: true).count }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  # A ghost vacates the `pending_live` slot, so this second POST used to succeed
  # with "Client invitation sent." where the unblocked one was refused — a flash
  # the inviter reads as a block (invariant I3).
  describe "a blocked re-invite is refused exactly like an unblocked one" do
    include ActiveJob::TestHelper

    def re_invite_outcome(workspace, project, email)
      2.times do |attempt|
        post workspace_project_client_invitations_path(workspace, project),
          params: { client_invitation: { email: email } }
        # Performs the mailer guard, which stamps the blocked row. only:, because
        # the user factory also queues CheckGravatarJob (network I/O).
        perform_enqueued_jobs(only: ActionMailer::MailDeliveryJob) if attempt.zero?
      end
      [ response.status, flash[:alert], project.invitations.where(email: email).count ]
    end

    it "returns the same status, flash and record count either way" do
      project = team_project
      workspace = project.workspace
      create(:invitation_block, inviter: project.created_by, email: "blocked@bigco.com")

      blocked = re_invite_outcome(workspace, project, "blocked@bigco.com")
      unblocked = re_invite_outcome(workspace, project, "open@bigco.com")

      expect(blocked).to eq(unblocked)
      expect(blocked).to eq([ 422, I18n.t("clientside.invitations.already_invited"), 1 ])
    end
  end

  it "lets the project's creator invite when their workspace role cannot manage members" do
    creator = create(:user)
    workspace = create(:user).workspaces.sole
    create(:membership, user: creator, workspace: workspace)
    project = create(:project, workspace: workspace, created_by: creator, clientside_enabled: true)
    sign_in(creator)

    expect {
      post workspace_project_client_invitations_path(workspace, project),
        params: { client_invitation: { email: "dana@bigco.com" } }
    }.to change { project.invitations.where(client: true).count }.by(1)
  end

  context "as a viewer (no manage_members permission)" do
    def sign_in_viewer_of(project)
      viewer = create(:user)
      create(:membership, :viewer, user: viewer, workspace: project.workspace)
      create(:project_membership, :viewer, user: viewer, project: project)
      sign_in(viewer)
    end

    it "denies new (redirect)" do
      project = team_project
      workspace = project.workspace
      sign_in_viewer_of(project)
      get new_workspace_project_client_invitation_path(workspace, project)
      expect(response).to have_http_status(:redirect)
    end

    it "denies create (redirect) and creates no invitation" do
      project = team_project
      workspace = project.workspace
      sign_in_viewer_of(project)
      expect {
        post workspace_project_client_invitations_path(workspace, project),
          params: { client_invitation: { email: "attacker@example.com" } }
      }.not_to change { Invitation.count }
      expect(response).to have_http_status(:redirect)
    end
  end
end
