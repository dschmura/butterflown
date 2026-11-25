# frozen_string_literal: true

require "rails_helper"

# The 2026-11 docs audit found the same sections written out on two pages, drifting apart.
RSpec.describe "docs topics with one owning page" do
  let(:pages) { Rails.root.glob("app/docs/{developer,user}/*.md").to_h { |path| [ path.basename(".md").to_s, path.read ] } }
  let(:owners) do
    {
      /^#+ Spec conventions\b/ => "testing",
      /^#+ (?:One runner at a time|"Another process is holding the test database")/ => "testing",
      /^\| (?:Protected branch|`protected_branch`) \|/ => "before-you-push"
    }
  end

  it "writes each owned topic out on its owner's page only" do
    strays = owners.flat_map do |topic, owner|
      expect(pages.fetch(owner)).to match(topic), "#{owner} no longer has #{topic.source}"
      pages.except(owner).select { |_, text| text.match?(topic) }.map { |page, _| "#{page}: #{topic.source}" }
    end

    expect(strays).to be_empty, "written out away from its owner:\n  #{strays.join("\n  ")}"
  end
end
