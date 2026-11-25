# frozen_string_literal: true

require "rails_helper"

# Preset cards said Solo-default and Single-tenant; later pages said personal and shared (2026-11 findability test).
RSpec.describe "preset page titles" do
  let(:docs) { Rails.root.join("app/docs/developer") }
  let(:code_names) do
    { "presets-solo" => "personal", "presets-single-tenant" => "shared",
      "presets-open-saas" => "personal + join links", "presets-none" => "none" }
  end
  let(:valid_values) { Rails.root.join("config/initializers/tenancy.rb").read[/valid_onboarding = \[(.*?)\]/, 1].scan(/:(\w+)/).flatten }

  def front_matter_title(page) = docs.join("#{page}.md").read[/\A---\n.*?^title: (.*?)$/m, 1]

  it "maps a page to every WORKSPACE_ON_SIGNUP value the app accepts" do
    expect(code_names.values.map { |name| name[/\A\w+/] }.uniq).to match_array(valid_values)
  end

  it "carries the code name in each preset's card title and heading" do
    code_names.each do |page, name|
      expect(front_matter_title(page)).to end_with("(#{name})")
      expect(docs.join("#{page}.md").read).to match(/^# .*\(`:?#{Regexp.escape(name.sub(' + join links', ''))}`/)
    end
  end

  it "names the code names on the presets overview card" do
    description = docs.join("presets.md").read[/^description: (.*)$/, 1]

    code_names.each_value { |name| expect(description).to include("(#{name})") }
  end
end
