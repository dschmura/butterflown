# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the deployment card and where the CI switches live" do
  let(:docs) { Rails.root.join("app/docs/developer") }
  let(:deployment) { docs.join("deployment.md").read }
  let(:section) do
    lambda do |page, heading|
      docs.join("#{page}.md").read[/^#+ #{Regexp.escape(heading)}\n.*?(?=^#+ |\z)/m] || raise("no #{heading} in #{page}")
    end
  end

  it "names backups and restore on the Backups card" do
    front = YAML.safe_load(docs.join("backups.md").read[/\A---\n(.*?)\n---\n/m, 1])

    expect(front["description"]).to match(/back(ing)? up/i)
    expect(front["keywords"].split).to include("backup", "restore")
  end

  it "says once where repository variables are set, and the switches link there" do
    owner = section.("changing-the-defaults", "How changes ship")

    expect(owner).to include("Settings → Secrets and variables → Actions → Variables")
    expect(section.("deployment", "6. Deploy from CI")).to include("](changing-the-defaults#how-changes-ship)")
    expect(section.("releasing", "When a release starts")).to include("](changing-the-defaults#how-changes-ship)")
  end

  it "credits bin/fork with the deploy names" do
    expect(section.("deployment", "2. Configure `config/deploy.yml`")).to include("`bin/fork` already renamed")
  end
end
