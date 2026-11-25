# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the common tasks page" do
  let(:docs) { Rails.root.join("app/docs") }
  let(:source) { docs.join("developer/common-tasks.md").read }
  let(:heading_ids) do
    lambda do |slug|
      html = Markdowndocs::MarkdownRenderer.render(docs.join("#{slug}.md").read.sub(/\A---\n.*?\n---\n/m, ""))
      Nokogiri::HTML5.fragment(html).css("[id]").map { |node| node["id"] }
    end
  end

  it "has an I want to list and a Something went wrong list" do
    expect(source).to include("## I want to", "## Something went wrong")
  end

  it "links every task to a heading that exists on its page" do
    links = source.scan(%r{\]\(/docs/((?:developer|user)/[a-z0-9-]+)#([^)]+)\)}).uniq
    broken = links.reject { |slug, anchor| heading_ids.(slug).include?(anchor) }

    expect(links.size).to be >= 10
    expect(broken).to be_empty, "no such heading: #{broken.map { |slug, anchor| "#{slug}##{anchor}" }.join(', ')}"
  end

  it "is the first developer page under Getting Started after the Quickstart" do
    developer_pages = Markdowndocs.configuration.categories.fetch("Getting Started").grep(%r{\Adeveloper/})

    expect(developer_pages.first(2)).to eq(%w[developer/quickstart developer/common-tasks])
  end

  it "is reachable from Troubleshooting" do
    expect(docs.join("developer/troubleshooting.md").read).to include("](/docs/developer/common-tasks)")
  end
end
