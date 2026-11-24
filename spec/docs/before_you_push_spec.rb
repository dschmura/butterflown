# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the before-you-push page" do
  let(:docs) { Rails.root.join("app/docs/developer") }
  let(:source) { docs.join("before-you-push.md").read }
  let(:pre_push_jobs) { YAML.load_file(Rails.root.join("lefthook.yml")).dig("pre-push", "commands").keys }

  it "names every pre-push check Lefthook can report, so a refused push leads somewhere" do
    expect(pre_push_jobs.size).to be >= 10

    missing = pre_push_jobs.reject { |job| source.include?("`#{job}`") }
    expect(missing).to be_empty, "pre-push checks the page doesn't name: #{missing.join(', ')}"
  end

  it "shows how to rerun one check by itself" do
    expect(source).to include("lefthook run pre-push --job")
  end

  it "says a page no system spec visits is not audited" do
    expect(source).to include("bin/test-plan --run", "axe", "system spec")
  end
end
