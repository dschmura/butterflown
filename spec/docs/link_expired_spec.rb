# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the Link expired? answer in the user guide" do
  let(:page) { Rails.root.join("app/docs/user/authentication.md").read }
  let(:answer) { page[/^### Link expired\?\n.*?(?=^#+ )/m] }

  it "quotes the message an expired link shows, and the lifetime the token really has" do
    expect(answer).to include(I18n.t("magic_link_callbacks.show.invalid", locale: :en))
    expect(Rails.root.join("app/models/magic_link_token.rb").read).to include("expires_at: 15.minutes.from_now")
    expect(answer).to include("15 minutes")
  end

  it "is found by a search for expired" do
    keywords = page[/^keywords: (.*)$/, 1]

    expect(keywords.split).to include("expired")
  end
end
