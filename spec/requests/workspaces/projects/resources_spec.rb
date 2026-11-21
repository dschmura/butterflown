require "rails_helper"

RSpec.describe "Project Resources", type: :request do
  def project_with_signed_in_creator
    user = create(:user)
    workspace = create(:workspace)
    create(:membership, :owner, user: user, workspace: workspace)
    project = create(:project, workspace: workspace, created_by: user)
    project.project_memberships.find_by!(user: user)
    Current.workspace = workspace
    Current.project = project
    sign_in(user)
    project
  end

  def add_resource(project, **attributes)
    create(:resource, project: project, created_by: project.created_by, **attributes)
  end

  def add_project_member(project, *traits)
    user = create(:user)
    create(:membership, user: user, workspace: project.workspace)
    create(:project_membership, *traits, project: project, user: user)
    user
  end

  describe "unauthenticated access" do
    it "redirects GET /workspaces/:slug/projects/:project_slug/resources to sign in" do
      get workspace_project_resources_path(workspace_slug: "any-slug", project_slug: "any-project")
      expect(response).to redirect_to(new_session_path)
    end
  end

  context "authenticated" do
    describe "GET index" do
      it "lists project resources" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        get workspace_project_resources_path(project.workspace, project)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(resource.title))
      end

      it "renders both the published and draft pills through UI::Badge" do
        project = project_with_signed_in_creator
        add_resource(project, status: "published")
        add_resource(project, status: "draft")

        get workspace_project_resources_path(project.workspace, project)

        html = Capybara.string(response.body)
        expect(html).to have_css("span.rounded-full.border-success-border",
          exact_text: I18n.t("workspaces.projects.resources.index.published"))
        expect(html).to have_css("span[data-variant='soft'][data-tone='neutral']",
          exact_text: I18n.t("workspaces.projects.resources.index.draft"))
      end
    end

    describe "GET new" do
      it "renders the new document form" do
        project = project_with_signed_in_creator
        get new_workspace_project_resource_path(project.workspace, project)
        expect(response).to have_http_status(:ok)
      end

      # C9: the type allowlist (it makes the later constantize safe) halts the
      # request as a before_action on every action that consumes the type.
      it "rejects an invalid resource type before the action body" do
        project = project_with_signed_in_creator
        get new_workspace_project_resource_path(project.workspace, project, type: "User")
        expect(response).to redirect_to(workspace_project_resources_path(project.workspace, project))
        expect(flash[:alert]).to eq(I18n.t("workspaces.projects.resources.invalid_type"))
      end
    end

    describe "POST create" do
      it "creates a document resource" do
        project = project_with_signed_in_creator
        expect {
          post workspace_project_resources_path(project.workspace, project), params: {
            resource: { title: "My Document", type: "Document" },
            document: { body: "Some content" }
          }
        }.to change(Resource, :count).by(1)
          .and change(Document, :count).by(1)
      end

      it "assigns created_by to current user" do
        project = project_with_signed_in_creator
        post workspace_project_resources_path(project.workspace, project), params: {
          resource: { title: "My Document", type: "Document" },
          document: { body: "Content" }
        }
        resource = Resource.find_by!(title: "My Document")
        expect(resource.created_by).to eq(project.created_by)
      end

      it "defaults to draft status" do
        project = project_with_signed_in_creator
        post workspace_project_resources_path(project.workspace, project), params: {
          resource: { title: "Draft Doc", type: "Document" },
          document: { body: "Draft" }
        }
        resource = Resource.find_by!(title: "Draft Doc")
        expect(resource).to be_draft
      end

      it "rejects invalid resource type without creating anything" do
        project = project_with_signed_in_creator
        expect {
          post workspace_project_resources_path(project.workspace, project), params: {
            resource: { title: "Bad Type", type: "User" },
            document: { body: "Content" }
          }
        }.not_to change(Resource, :count)
        expect(response).to redirect_to(workspace_project_resources_path(project.workspace, project))
        expect(flash[:alert]).to eq(I18n.t("workspaces.projects.resources.invalid_type"))
      end
    end

    describe "POST create with blank title" do
      it "returns unprocessable entity with the error bound to the field (#753)" do
        project = project_with_signed_in_creator
        post workspace_project_resources_path(project.workspace, project), params: {
          resource: { title: "", type: "Document" },
          document: { body: "RetainedBody" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        page = Capybara.string(response.body)
        # The invalid record's errors render inside the alert region, linked to the
        # field (regression: the old rescue rebuilt an unvalidated record).
        expect(page.find("[role='alert']")).to have_link("Title can't be blank", href: "#resource_title")
        # Field-level association contract (#753): aria-invalid + describedby
        # pointing at the rendered error paragraph.
        expect(page).to have_css("input#resource_title[aria-invalid='true']")
        describedby = page.find("input#resource_title")["aria-describedby"]
        expect(describedby).to include("resource_title-error")
        expect(page).to have_css("p#resource_title-error", text: "can't be blank")
        # ...and the submitted body survives the re-render, bound to the
        # document form — not just the string appearing anywhere in the body.
        expect(page).to have_css("form [name='document[body]']", visible: :all)
        expect(page.find("[name='document[body]']", visible: :all).value).to include("RetainedBody")
      end

      # #753: no native required anywhere on the form, or the browser bubble
      # blocks the submit and the server-rendered error path is unreachable.
      it "renders the form without native required (aria-only contract)" do
        project = project_with_signed_in_creator
        get new_workspace_project_resource_path(project.workspace, project, type: "Document")
        page = Capybara.string(response.body)
        expect(page).to have_css("input#resource_title[aria-required='true']")
        expect(page).to have_no_css("input#resource_title[required]")
      end
    end

    # #752: position renders no control on this form, so its summary entry is
    # plain text, not a link to a missing anchor.
    describe "POST create with a position error (no rendered control)" do
      it "shows the message as text, not a dead anchor" do
        project = project_with_signed_in_creator
        allow_any_instance_of(Workspaces::Projects::ResourcesController)
          .to receive(:resource_params).and_return({ title: "Valid", position: -1 })

        post workspace_project_resources_path(project.workspace, project), params: {
          resource: { title: "Valid", type: "Document" }, document: { body: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        summary = Capybara.string(response.body).find("[role='alert']")
        expect(summary).to have_text("Position must be greater than or equal to 0")
        expect(summary).to have_no_css("a[href='#resource_position']")
      end
    end

    # #747: a failing resourceable's own errors reach the summary; the stub stands
    # in for a validating resourceable type, since Document has no validations.
    describe "POST create when the resourceable is invalid" do
      it "renders the resourceable's errors in the summary" do
        project = project_with_signed_in_creator
        allow(Document).to receive(:create!) do
          doc = Document.new
          doc.errors.add(:body, "is too plain")
          raise ActiveRecord::RecordInvalid.new(doc)
        end

        post workspace_project_resources_path(project.workspace, project), params: {
          resource: { title: "Valid title", type: "Document" }, document: { body: "x" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(Capybara.string(response.body).find("[role='alert']")).to have_text("Body is too plain")
      end
    end

    # #754: label and editor ride the data-slot adjacency, and the aria contract
    # reaches the editor host (Lexxy forwards aria-* onto the contenteditable).
    describe "document body field structure" do
      it "renders label and editor in data-slot rhythm on new and edit, with the shared label key" do
        project = project_with_signed_in_creator
        get new_workspace_project_resource_path(project.workspace, project, type: "Document")
        page = Capybara.string(response.body)
        expect(page).to have_css(
          "[data-slot='label'][for='document_body']",
          text: I18n.t("workspaces.projects.resources.form.body_label")
        )
        expect(page).to have_css("[data-slot='control'] #document_body", visible: :all)

        resource = add_resource(project)
        get edit_workspace_project_resource_path(project.workspace, project, resource)
        page = Capybara.string(response.body)
        expect(page).to have_css("[data-slot='label'][for='document_body']")
        expect(page).to have_css("[data-slot='control'] #document_body", visible: :all)
      end

      it "renders the editor with alt-text authoring on" do
        project = project_with_signed_in_creator
        get new_workspace_project_resource_path(project.workspace, project, type: "Document")
        editor = Capybara.string(response.body).find("#document_body", visible: :all)
        expect(editor["data-action-text-supports-alt"]).to eq("true")
      end
    end

    # #757: SR users re-orient by document title after Turbo's 422 re-render;
    # the count mirrors the summary the page focuses.
    describe "error count in the page title" do
      it "prefixes the title on a 422 and leaves a clean render unchanged" do
        project = project_with_signed_in_creator
        post workspace_project_resources_path(project.workspace, project), params: {
          resource: { title: "", type: "Document" }, document: { body: "" }
        }
        expect(Capybara.string(response.body).find("title", visible: :all).text).to include("1 error")

        get new_workspace_project_resource_path(project.workspace, project, type: "Document")
        title = Capybara.string(response.body).find("title", visible: :all).text
        expect(title).not_to include("error")
      end
    end

    describe "GET show" do
      it "displays the resource" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        get workspace_project_resource_path(project.workspace, project, resource)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(resource.title))
      end

      it "renders the draft pill through UI::Badge" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        get workspace_project_resource_path(project.workspace, project, resource)

        html = Capybara.string(response.body)
        expect(html).to have_css("span[data-variant='soft'][data-tone='neutral']",
          exact_text: I18n.t("workspaces.projects.resources.index.draft"))
      end

      it "denies non-project-members" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        outsider = create(:user)
        create(:membership, user: outsider, workspace: project.workspace)
        sign_in(outsider)
        get workspace_project_resource_path(project.workspace, project, resource)
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "PATCH update" do
      it "updates the resource title" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        patch workspace_project_resource_path(project.workspace, project, resource), params: {
          resource: { title: "Updated Title" }
        }
        expect(resource.reload.title).to eq("Updated Title")
        expect(response).to redirect_to(workspace_project_resource_path(project.workspace, project, resource))
        expect(flash[:notice]).to eq(I18n.t("workspaces.projects.resources.update.success"))
      end
    end

    describe "PATCH update with blank title" do
      it "returns unprocessable entity" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        patch workspace_project_resource_path(project.workspace, project, resource), params: {
          resource: { title: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "re-renders the edit form with a destructive alert listing the errors" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        patch workspace_project_resource_path(project.workspace, project, resource), params: {
          resource: { title: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)

        # #729: the edit form's error summary comes from UI::FormBuilder, so this
        # asserts the message inside the role="alert" region, not old markup.
        html = Capybara.string(response.body)
        expect(html.find("[role='alert']")).to have_text("Title can't be blank")
      end
    end

    describe "DELETE destroy" do
      it "soft deletes the resource" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        delete workspace_project_resource_path(project.workspace, project, resource)
        expect(resource.reload).to be_discarded
        expect(response).to redirect_to(workspace_project_resources_path(project.workspace, project))
        expect(flash[:notice]).to eq(I18n.t("workspaces.projects.resources.destroy.success"))
      end

      it "leaves the deleted resource unreachable" do
        project = project_with_signed_in_creator
        resource = add_resource(project)
        delete workspace_project_resource_path(project.workspace, project, resource)
        get workspace_project_resource_path(project.workspace, project, resource)
        expect(flash[:alert]).to eq(I18n.t("errors.not_found"))
      end
    end

    # Reordering is the update of a position nested under the resource (#1007).
    describe "PATCH /workspaces/:slug/projects/:slug/resources/:id/position" do
      def resource_among_siblings(project)
        resource = add_resource(project, position: 0)
        (1..3).each { |position| add_resource(project, position: position) }
        resource
      end

      it "updates the resource position" do
        project = project_with_signed_in_creator
        resource = resource_among_siblings(project)
        patch workspace_project_resource_position_path(project.workspace, project, resource), params: {
          resource: { position: 3 }
        }
        expect(resource.reload.position).to eq(3)
      end

      it "clamps negative position to 0" do
        project = project_with_signed_in_creator
        resource = resource_among_siblings(project)
        patch workspace_project_resource_position_path(project.workspace, project, resource), params: {
          resource: { position: -5 }
        }
        expect(resource.reload.position).to eq(0)
      end
    end

    describe "PATCH position denied for viewer" do
      it "denies viewer from repositioning" do
        project = project_with_signed_in_creator
        viewer = add_project_member(project, :viewer)
        resource = add_resource(project, position: 0)
        sign_in(viewer)
        patch workspace_project_resource_position_path(project.workspace, project, resource), params: {
          resource: { position: 5 }
        }
        expect(resource.reload.position).to eq(0)
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "authorization" do
      it "denies viewers from creating" do
        project = project_with_signed_in_creator
        viewer = add_project_member(project, :viewer)
        sign_in(viewer)
        post workspace_project_resources_path(project.workspace, project), params: {
          resource: { title: "Nope", type: "Document" },
          document: { body: "Nope" }
        }
        expect(response).to have_http_status(:redirect)
      end
    end

    describe "authorization - editor cannot update others' resources" do
      it "denies editor from updating a resource they didn't create" do
        project = project_with_signed_in_creator
        editor = add_project_member(project)
        resource = add_resource(project)
        sign_in(editor)
        patch workspace_project_resource_path(project.workspace, project, resource), params: {
          resource: { title: "Hacked Title" }
        }
        expect(resource.reload.title).not_to eq("Hacked Title")
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
