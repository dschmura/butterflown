# frozen_string_literal: true

require "rails_helper"

# Code points readers at "/docs/developer/<page> (Section)"; a renamed heading must take its pointers with it.
RSpec.describe "section citations in code" do
  let(:normalize) { ->(text) { text.delete("`*").gsub(/\s+/, " ").strip.downcase } }
  let(:files) do
    tracked_files.grep_v(%r{\A(app/docs|spec|changelog\.d)/|\ACHANGELOG\.md\z})
      .map { |path| Rails.root.join(path) }.select { |path| path.file? && !path.binread.include?("\0") }
  end
  let(:citations) do
    files.flat_map do |file|
      joined = file.read.gsub(%r{\n\s*(?:#|//)\s*}, " ")
      joined.scan(%r{/docs/developer/([a-z0-9-]+) \(([^)]+?)(?: section)?\)}).map { |page, names| [ file, page, names ] }
    end
  end

  def targets(page)
    path = Rails.root.join("app/docs/developer/#{page}.md")
    return [] unless path.exist?

    source = path.read
    labels = source.scan(/^#+ (.+)$/).flatten + source.scan(/\*\*([^*\n]+?)\.?\*\*/).flatten
    labels.flat_map { |label| [ normalize.(label), normalize.(label.sub(/\A\d+\. /, "")) ] }
  end

  def resolves?(name, labels)
    labels.any? { |label| label == name || (label.start_with?(name) && label[name.size].to_s !~ /[a-z0-9]/) }
  end

  it "name a heading or bold label on the cited page" do
    missing = citations.flat_map do |file, page, names|
      labels = targets(page)
      names.split(/,\s*/).map { |name| normalize.(name) }.reject { |name| resolves?(name, labels) }
        .map { |name| "#{file.relative_path_from(Rails.root)}: #{page} (#{name})" }
    end

    expect(missing).to be_empty, "citations with no matching heading:\n  #{missing.uniq.join("\n  ")}"
  end

  it "sees the citations it checks" do
    expect(citations.size).to be > 50
  end
end
