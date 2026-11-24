# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the docs on production mail" do
  let(:docs) { Rails.root.join("app/docs") }
  let(:section) do
    lambda do |page, heading|
      docs.join("#{page}.md").read[/^#+ #{Regexp.escape(heading)}\n.*?(?=^#+ )/m] || raise("no #{heading} in #{page}")
    end
  end

  it "names bin/production-setup for a first setup wherever it says how to set production mail up" do
    places = {
      "developer/deployment §4" => section.("developer/deployment", "4. Configure outbound mail"),
      "user/emails SMTP Setup" => section.("user/emails", "SMTP Setup")
    }

    places.each do |place, text|
      expect(text).to include("bin/production-setup"), "#{place} doesn't name bin/production-setup"
      expect(text.index("bin/production-setup")).to be < text.index("bin/mail-setup"), "#{place} names bin/mail-setup first"
    end
  end

  it "warns in the Quickstart that a new Postmark account mails only its own domain until approved" do
    expect(section.("developer/quickstart", "4. Production secrets and mail"))
      .to include("Postmark", "deployment#postmark-the-worked-default")
  end
end
