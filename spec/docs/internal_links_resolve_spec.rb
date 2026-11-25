# frozen_string_literal: true

require "rails_helper"

# A moved or renamed doc fails here until every link to it is fixed in the same change.
RSpec.describe "links to docs pages" do
  let(:pages) { Rails.root.glob("app/docs/{user,developer}/*.md").to_set { |path| "#{path.parent.basename}/#{path.basename('.md')}" } }
  let(:citing_files) do
    Rails.root.glob("{app,lib,config,.github}/**/*.{md,rb,erb,yml}") + Rails.root.glob("bin/*").select(&:file?) + [ Rails.root.join("README.md") ]
  end

  it "point at a page that exists, wherever the app cites a /docs/ path" do
    broken = citing_files.flat_map do |file|
      file.read.scan(%r{/docs/((?:user|developer)/[a-z0-9_-]+)(?![A-Za-z0-9_-])}).flatten
        .reject { |slug| pages.include?(slug) }
        .map { |slug| "#{file.relative_path_from(Rails.root)}: /docs/#{slug}" }
    end

    expect(broken).to be_empty, "links to missing docs pages:\n  #{broken.uniq.join("\n  ")}"
  end

  it "point at a page in the same guide, for a doc's relative links" do
    broken = Rails.root.glob("app/docs/{user,developer}/*.md").flat_map do |file|
      guide = file.parent.basename.to_s
      file.read.scan(%r{\]\(([a-z0-9_-]+)(?:#[^)]*)?\)}).flatten
        .reject { |slug| pages.include?("#{guide}/#{slug}") }
        .map { |slug| "#{file.relative_path_from(Rails.root)}: (#{slug})" }
    end

    expect(broken).to be_empty, "relative links to missing docs pages:\n  #{broken.uniq.join("\n  ")}"
  end

  it "sees the links it checks" do
    expect(citing_files.sum { |file| file.read.scan(%r{/docs/(?:user|developer)/}).size }).to be > 100
  end
end
