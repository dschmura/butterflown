# frozen_string_literal: true

require "rails_helper"

# A fork that set _brand.css alone found its workspace pages still sky blue (2026-11 findability test).
RSpec.describe "what a rebrand recolors, in the developer docs" do
  let(:docs) { Rails.root.join("app/docs/developer") }
  let(:retheme) { docs.join("ui-patterns.md").read[/^Map Tailwind color families.*?(?=^### )/m] }

  it "says beside the retheme recipe that pages inside a workspace keep the workspace's own color" do
    expect(retheme).to include("does not change that hue", "hue #{Identity::DEFAULT_HUE}", "(#workspace-branding)")
  end

  it "says a personal workspace takes its color from the neutral family" do
    expect(retheme).to include("takes its color from the neutral family, `--neutral-*`")
  end

  it "points Forking's brand-colors row at the caveat" do
    row = docs.join("forking.md").read.lines.find { |line| line.start_with?("| Brand colors") }

    expect(row).to include("ui-patterns#what-_brandcss-does-not-reach")
  end
end
