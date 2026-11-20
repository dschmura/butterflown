require "rails_helper"

RSpec.describe "Deleting a project resource", type: :system do
  def kickoff_notes
    author = create(:user)
    project = create(:project, workspace: author.workspaces.sole, created_by: author)
    create(:resource, project: project, created_by: author, title: "Kickoff notes")
  end

  def add_project_viewer(project, workspace_role: nil)
    user = create(:user)
    create(:membership, *[ workspace_role ].compact, user: user, workspace: project.workspace)
    create(:project_membership, :viewer, project: project, user: user)
    user
  end

  context "as the resource's author" do
    it "deletes it from its page, through a confirm dialog" do
      resource = kickoff_notes
      project = resource.project
      sign_in_via_form(resource.created_by)

      visit workspace_project_resource_path(project.workspace, project, resource)
      click_button I18n.t("workspaces.projects.resources.show.delete")
      expect(page).to have_css("dialog[open]")
      expect(page).to have_text(I18n.t("workspaces.projects.resources.destroy.confirm"))

      within("dialog[open]") { click_button I18n.t("workspaces.projects.resources.destroy.confirm_action") }

      expect(page).to have_current_path(workspace_project_resources_path(project.workspace, project))
      expect(page).to have_text("Resource deleted.")
      expect(page).to have_no_link("Kickoff notes")
      expect(resource.reload).to be_discarded
    end

    it "passes axe AAA with the delete dialog open, both themes" do
      resource = kickoff_notes
      project = resource.project
      sign_in_via_form(resource.created_by)
      axe_options = { runOnly: { type: "tag", values: [ "wcag2aaa" ] } }

      visit workspace_project_resource_path(project.workspace, project, resource)
      click_button I18n.t("workspaces.projects.resources.show.delete")
      expect(page).to have_css("dialog[open]")

      expect(axe_clean_in_both_themes?(axe_options)).to be(true),
        "Accessibility violations:\n#{axe_violations_in_both_themes(axe_options).join("\n")}"
    end
  end

  context "as a project viewer who did not write it" do
    it "offers no Delete" do
      resource = kickoff_notes
      project = resource.project
      sign_in_via_form(add_project_viewer(project))

      visit workspace_project_resource_path(project.workspace, project, resource)

      expect(page).to have_css("h1", text: "Kickoff notes")
      expect(page).to have_no_button(I18n.t("workspaces.projects.resources.show.delete"))
    end
  end

  # destroy? grants manage_workspace, update? does not: an owner who only views can delete but not edit.
  context "as a workspace owner viewing someone else's resource" do
    it "offers Delete but not Edit" do
      resource = kickoff_notes
      project = resource.project
      sign_in_via_form(add_project_viewer(project, workspace_role: :owner))

      visit workspace_project_resource_path(project.workspace, project, resource)

      expect(page).to have_css("h1", text: "Kickoff notes")
      expect(page).to have_button(I18n.t("workspaces.projects.resources.show.delete"))
      expect(page).to have_no_link(I18n.t("workspaces.projects.resources.show.edit"))
    end
  end
end
