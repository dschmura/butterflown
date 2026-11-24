require "rails_helper"

RSpec.describe "The how-code-ships guide in a browser", type: :system do
  let(:axe_options) { { runOnly: { type: "tag", values: [ "wcag2aaa" ] } } }

  before { visit "/docs/developer/how-code-ships" }

  it "passes axe-core at WCAG 2.2 AAA in both themes, with every drawer open" do
    page.all("ol.walkthrough details summary").each(&:click)

    expect(page).to have_css("ol.walkthrough details[open]", count: 12)
    expect(axe_clean_in_both_themes?(axe_options)).to be(true),
      "AAA violations:\n#{axe_violations_in_both_themes(axe_options).join("\n")}"
  end

  it "keeps each step's commands closed until its drawer is opened" do
    within("#step-1") do
      expect(page).to have_no_css("code", text: "bin/dev")

      find("summary", text: "Commands").click

      expect(page).to have_css("code", text: "bin/dev")
    end
  end

  it "draws the branch lanes beside the steps on a wide screen" do
    expect(page).to have_css(".lane-head", text: "release")
    expect(find("#step-7 .lane-cell > svg")).to be_visible
  end
end
