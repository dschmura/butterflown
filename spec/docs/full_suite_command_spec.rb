# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the docs' full-suite command" do
  let(:pages) { Dir[Rails.root.join("app/docs/**/*.md")] + [ Rails.root.join("README.md").to_s ] }
  let(:bare_full_suite) { /^\s*(?:mise exec -- )?bundle exec rspec\s*$/ }

  it "is bin/parallel-rspec, which seeds every worker database; a bare rspec run is labeled for focused use" do
    expect(pages.size).to be > 40

    offenders = pages.flat_map do |page|
      File.foreach(page).with_index(1).filter_map do |line, number|
        "#{Pathname(page).relative_path_from(Rails.root)}:#{number}" if line.match?(bare_full_suite)
      end
    end

    expect(offenders).to be_empty, "a bare full-suite rspec command: #{offenders.join(', ')}"
  end
end
