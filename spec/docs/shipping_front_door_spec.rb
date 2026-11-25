# frozen_string_literal: true

require "rails_helper"

# 2026-11 findability test: shipping answers were split across pages, and a solo reader couldn't tell which setup applied.
RSpec.describe "How your code reaches users as the front door to shipping" do
  let(:docs) { Rails.root.join("app/docs/developer") }

  it "is what Releasing points a newcomer to before anything else" do
    opening = docs.join("releasing.md").read[/^# Releasing\n\n(.*?)\n\n/m, 1]

    expect(opening).to include("New here?", "(how-code-ships)")
  end

  it "comes first in the Quickstart's details for shipping" do
    step = docs.join("quickstart.md").read[/^## 8\. Ship changes\n.*?(?=^## )/m]

    expect(step.index("(how-code-ships)")).to be < step.index("(releasing)")
  end

  it "tells someone working alone where their setup differs, before the steps" do
    intro = docs.join("how-code-ships.md").read[/^# How your code reaches users\n.*?(?=^## )/m]

    expect(intro).to include("Working alone?", "(#when-a-switch-is-off)")
  end
end
