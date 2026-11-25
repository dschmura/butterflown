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

  it "points Extending at the developer page instead of repeating it" do
    section = docs.join("developer/extending.md").read[/^## Clientside.*?(?=^## )/m]

    expect(section).to include("](/docs/developer/clientside)")
    expect(section).not_to include("Clientside::BaseController")
  end
end
