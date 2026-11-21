require "rails_helper"

RSpec.describe "Workspace Projects", type: :request do
  def sign_in_owner
    owner = create(:membership, :owner)
    Current.workspace = owner.workspace
    sign_in(owner.user)
    owner
  end

  def project_in(owner)
    create(:project, workspace: owner.workspace, created_by: owner.user)
  end

  describe "unauthenticated access" do
    it "redirects GET /workspaces/:slug/projects to sign in" do
      get workspace_projects_path(workspace_slug: "any-slug")
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "authenticated" do
    describe "GET /workspaces/:workspace_slug/projects" do
      it "lists projects" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        get workspace_projects_path(workspace)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(project.name))
      end

      # #687: the index listed every kept project to any member; the scope
      # shows members their projects and workspace managers all of them.
      describe "index visibility (ProjectPolicy::Scope)" do
        def visibility_cast(owner)
          plain_member = add_member(owner.workspace).user
          create(:project, workspace: owner.workspace, created_by: plain_member, name: "Mine Alone")
          not_mine = create(:project, workspace: owner.workspace, created_by: owner.user, name: "Somebody Elses")
          [ plain_member, not_mine ]
        end

        it "shows a plain member only the projects they belong to" do
          owner = sign_in_owner
          workspace = owner.workspace
          plain_member, = visibility_cast(owner)
          sign_in(plain_member)
          get workspace_projects_path(workspace)

          expect(response.body).to include("Mine Alone")
          expect(response.body).not_to include(CGI.escapeHTML("Somebody Elses"))
        end

        it "shows a workspace manager every project" do
          owner = sign_in_owner
          workspace = owner.workspace
          visibility_cast(owner)
          get workspace_projects_path(workspace)

          expect(response.body).to include("Mine Alone")
          expect(response.body).to include(CGI.escapeHTML("Somebody Elses"))
        end

        it "scopes the archived section the same way" do
          owner = sign_in_owner
          workspace = owner.workspace
          plain_member, not_mine = visibility_cast(owner)
          not_mine.archive!
          sign_in(plain_member)
          get workspace_projects_path(workspace)

          expect(response.body).not_to include(CGI.escapeHTML("Somebody Elses"))
        end
      end

      it "renders the project initials through the avatar component" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        get workspace_projects_path(workspace)
        html = Capybara.string(response.body)
        # Scoped to the project card: the layout's workspace switcher renders the
        # same avatar markup (same size, substring-matchable initials), so an
        # unscoped, non-exact assertion can pass with the card's avatar deleted.
        card = html.find("a[href='#{workspace_project_path(workspace, project)}']")
        expect(card).to have_css("span.w-10.h-10[aria-hidden='true']", exact_text: project.initials)
        # The initials are aria-hidden, so the adjacent name is the card's whole
        # accessible name — assert it directly.
        expect(card).to have_text(project.name)
      end

      it "renders an attached logo through the component's recovery pair" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        project.logo.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
          filename: "logo.png",
          content_type: "image/png"
        )

        get workspace_projects_path(workspace)

        html = Capybara.string(response.body)
        card = html.find("a[href='#{workspace_project_path(workspace, project)}']")
        expect(card).to have_css(
          "[data-controller='avatar'] img[aria-hidden='true'][src*='/rails/active_storage/']"
        )
        expect(card).to have_css("span[data-avatar-target='fallback']", visible: :hidden)
      end

      # Bullet.raise fails this on a per-row logo_attachment N+1; only the
      # multi-row fixture trips Bullet's threshold detector.
      it "renders without N+1 queries (regression guard)" do
        owner = sign_in_owner
        workspace = owner.workspace
        projects = (1..3).map do |i|
          create(:project, workspace: workspace, created_by: owner.user, name: "Project #{i}")
        end

        get workspace_projects_path(workspace)

        expect(response).to have_http_status(:ok)
        projects.each do |project|
          expect(response.body).to include(CGI.escapeHTML(project.name))
        end
      end
    end

    describe "GET /workspaces/:workspace_slug/projects/new" do
      it "renders the new form" do
        workspace = sign_in_owner.workspace
        get new_workspace_project_path(workspace)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /workspaces/:workspace_slug/projects" do
      it "creates a project and assigns creator role" do
        owner = sign_in_owner
        workspace = owner.workspace
        user = owner.user
        expect {
          post workspace_projects_path(workspace), params: { project: { name: "New Project", description: "Client launch" } }
        }.to change(Project, :count).by(1)

        project = Project.find_by!(name: "New Project")
        expect(project.description).to eq("Client launch")
        pm = project.project_memberships.find_by(user: user)
        expect(pm).to be_creator
        expect(flash[:notice]).to eq(I18n.t("workspaces.projects.create.success"))
      end

      it "enforces max_projects" do
        owner = sign_in_owner
        workspace = owner.workspace
        workspace.update!(max_projects: 1)
        project_in(owner)
        post workspace_projects_path(workspace), params: { project: { name: "Over Limit" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "GET /workspaces/:workspace_slug/projects/:slug" do
      it "shows the project" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        get workspace_project_path(workspace, project)
        expect(response).to have_http_status(:ok)
      end

      # #746 (2.4.9 Link Purpose, AAA): "Edit" alone names no object out of
      # context. Literal string on purpose: I18n.t would move with a locale edit.
      it "names the edit link with its object for out-of-context reading" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        get workspace_project_path(workspace, project)
        page = Capybara.string(response.body)
        expect(page).to have_link(I18n.t("workspaces.projects.show.edit"), href: edit_workspace_project_path(workspace, project))
        expect(page).to have_no_link("Edit", exact: true)
      end

      it "renders the header initials through the avatar component" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        get workspace_project_path(workspace, project)
        html = Capybara.string(response.body)
        expect(html).to have_css("span.w-16.h-16[aria-hidden='true']", exact_text: project.initials)
        # The initials are aria-hidden; the h1 carries the accessible name.
        expect(html).to have_css("h1", text: project.name)
      end

      it "denies non-project-members" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        other = add_member(workspace).user
        sign_in(other)
        get workspace_project_path(workspace, project)
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "PATCH /workspaces/:workspace_slug/projects/:slug" do
      it "updates the project" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        patch workspace_project_path(workspace, project), params: { project: { name: "Updated", description: "New scope" } }
        expect(project.reload.name).to eq("Updated")
        expect(project.description).to eq("New scope")
        expect(flash[:notice]).to eq(I18n.t("workspaces.projects.update.success"))
      end
    end

    describe "DELETE /workspaces/:workspace_slug/projects/:slug" do
      it "soft deletes the project" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        delete workspace_project_path(workspace, project)
        expect(project.reload).to be_discarded
      end
    end

    # Archive/restore moved to spec/requests/workspaces/projects/archivals_spec.rb with the resource (#1007).

    describe "GET /workspaces/:workspace_slug/projects/:slug/edit" do
      it "renders the edit form" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        get edit_workspace_project_path(workspace, project)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /workspaces/:workspace_slug/projects with invalid params" do
      it "returns unprocessable entity for blank name" do
        workspace = sign_in_owner.workspace
        post workspace_projects_path(workspace), params: { project: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "PATCH /workspaces/:workspace_slug/projects/:slug with invalid params" do
      it "returns unprocessable entity for blank name" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        patch workspace_project_path(workspace, project), params: { project: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "GET /workspaces/:workspace_slug/projects/:slug with nonexistent slug" do
      it "redirects to projects list" do
        workspace = sign_in_owner.workspace
        get workspace_project_path(workspace, "nonexistent-slug")
        expect(response).to redirect_to(workspace_projects_path(workspace))
      end
    end

    describe "discarded projects" do
      it "are excluded from show" do
        owner = sign_in_owner
        workspace = owner.workspace
        project = project_in(owner)
        project.discard!
        get workspace_project_path(workspace, project)
        expect(response).to redirect_to(workspace_projects_path(workspace))
      end
    end
  end
end
