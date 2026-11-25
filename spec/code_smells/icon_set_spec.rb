# frozen_string_literal: true

require "rails_helper"

# icon.png shipped as Rails' red-circle placeholder long after the rest of the set became the mark.
RSpec.describe "the favicon and PWA icon set" do
  it "draws icon.png from the same 512px artwork as the manifest's icon" do
    expect(Rails.root.join("public/icon.png").binread).to eq(Rails.root.join("public/icon-512.png").binread)
  end
end
