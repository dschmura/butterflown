# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the user guide's people tasks" do
  let(:user_docs) { Rails.root.join("app/docs/user") }
  let(:section) do
    lambda do |page, heading|
      user_docs.join("#{page}.md").read[/^#+ #{Regexp.escape(heading)}\n.*?(?=^#+ |\z)/m] || raise("no #{heading} in #{page}")
    end
  end

  it "names the roles that see every project, from the roles that really hold manage_workspace" do
    see_all = Role::SYSTEM_DEFAULTS.select { |_, role| role[:permissions]["manage_workspace"] }.map { |_, role| role[:name] }
    others = Role::SYSTEM_DEFAULTS.map { |_, role| role[:name] } - see_all
    answer = section.("projects", "Who sees which projects")

    expect(see_all).to eq([ "Owner" ])
    expect(answer).to include("Owners see every")
    others.each { |name| expect(answer).to include(name) }
  end

  it "answers inviting a colleague and removing someone who left as tasks, linked to project visibility" do
    invite = section.("workspaces", "Invite a colleague")

    expect(invite).to include("](/docs/user/projects#who-sees-which-projects)")
    expect(section.("workspaces", "Remove someone who left")).to include("Deactivate")
    expect(section.("projects", "Remove someone from one project only")).to include("still a member of the")
  end

  it "titles the invitations page by what the reader is doing" do
    expect(user_docs.join("invitations.md").read).to start_with("---\ntitle: Accept an Invitation\n")
  end
end
