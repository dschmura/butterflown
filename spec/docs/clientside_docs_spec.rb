# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the Clientside docs" do
  let(:docs) { Rails.root.join("app/docs") }
  let(:user_page) { docs.join("user/clientside.md").read }
  let(:developer_page) { docs.join("developer/clientside.md").read }

  it "keeps the internals on the developer page" do
    %w[ClientAccess Clientside::BaseController authenticated_home_path accept_client_invitation! client_visible_resources].each do |internal|
      expect(developer_page).to include(internal)
    end
  end

  it "moves the internals off the user page" do
    expect(user_page).not_to match(/Clientside::BaseController|authenticated_home_path|```|Fork seams/)
  end

  it "leaves the user page free of code" do
    expect(user_page).not_to match(/Controller|ClientAccess|```|`/)
  end

  it "walks the user through the screens by the labels they show" do
    labels = %w[
      clientside.settings.link clientside.settings.save clientside.invitations.new.link
      clientside.invitations.new.email_label clientside.invitations.new.company_label clientside.invitations.new.submit
      workspaces.projects.resources.edit.share_with_client workspaces.projects.resources.edit.submit
      invitation_mailer.invite_client.action clientside.projects.show.shared_with_you
    ].map { |key| I18n.t(key) } + [ I18n.t("clientside.settings.toggle_label", project: "project") ]

    labels.each { |label| expect(user_page).to include("**#{label}**") }
  end

  it "points Project Collaboration at the user page instead of repeating it" do
    section = docs.join("user/projects.md").read[/^## Share with a client.*?(?=^## )/m]

    expect(section).to include("](/docs/user/clientside)")
    expect(section).not_to match(/Controller|`/)
  end

  it "points Extending at the developer page instead of repeating it" do
    section = docs.join("developer/extending.md").read[/^## Clientside.*?(?=^## )/m]

    expect(section).to include("](/docs/developer/clientside)")
    expect(section).not_to include("Clientside::BaseController")
  end
end
