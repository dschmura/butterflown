require "rails_helper"
require "nokogiri"

RSpec.describe "The how-code-ships guide" do
  let(:source) { Rails.root.join("app/docs/developer/how-code-ships.md").read }
  let(:rendered) { Nokogiri::HTML5.fragment(Markdowndocs::MarkdownRenderer.render(source.sub(/\A---\n.*?\n---\n/m, ""))) }
  let(:steps) { rendered.css("ol.walkthrough > li[id^='step-']") }

  it "walks a PR through twelve numbered steps, in order, after the renderer has sanitized them" do
    expect(steps.map { |step| step["id"] }).to eq((1..12).map { |n| "step-#{n}" })
    steps.each { |step| expect(step.at_css("h3")&.text).to be_present }
  end

  it "gives every step a closed drawer of commands that ends by saying when to move on" do
    steps.each do |step|
      drawer = step.at_css("details")

      expect(drawer).to be_present, "#{step['id']} has no drawer"
      expect(drawer["open"]).to be_nil
      expect(drawer.at_css("summary").text.strip).to eq("Commands and next step")
      expect(drawer.css("code")).not_to be_empty
      expect(drawer.text).to include("Move on when")
    end
  end

  it "marks each step on its branch's lane, so the git graph survives the sanitizer" do
    steps.each do |step|
      expect(step.at_css("svg line, svg path")).to be_present, "#{step['id']} lost its lane drawing"
    end
  end

  it "cites only bin/ scripts the template ships" do
    cited = source.scan(%r{\bbin/[a-z][a-z0-9_-]*}).uniq

    expect(cited).to include("bin/release", "bin/kamal", "bin/dev")
    expect(cited.reject { |script| Rails.root.join(script).exist? }).to be_empty
  end

  it "colors with the semantic token classes only, never a raw color value" do
    expect(source).not_to match(/(?<![&\w])#\h{3}(?:\h{3})?\b|oklch\(|rgba?\(|hsla?\(|-\[#/)
  end

  it "says a new fork starts with every switch off, and what each switch changes" do
    expect(rendered.text).to include("A new fork starts solo")
    expect(rendered.css("a[href='#when-a-switch-is-off']")).not_to be_empty
    expect(rendered.at_css("#when-a-switch-is-off")).to be_present
    expect(rendered.text).to include("AUTO_RELEASE", "DEPLOY_STAGING", "DEPLOY_PRODUCTION", "bin/branch-rules")
  end

  it "links the urgent-fix route from the top of the page" do
    expect(rendered.at_css("#urgent-fix")).to be_present
    expect(rendered.css("a[href='#urgent-fix']")).not_to be_empty
  end
end
