# frozen_string_literal: true

require "rails_helper"

# Phrases a literal reader couldn't parse in the 2026-11 findability test, retired for plain words.
RSpec.describe "plain words in the developer docs" do
  let(:docs) { Rails.root.join("app/docs/developer") }
  let(:retired) do
    {
      "how-code-ships" => [ "practice server", "every switch on", "can pause here", "carries on by itself",
                            "carry on by themselves", "has moved on", "drift apart", "Once the release is named" ],
      "releasing" => [ "built around attention", "as it stood", "drive-by", "send it first", "widens a PR" ],
      "extending" => [ "action-at-a-distance", "load-bearing", "defense-in-depth backstop", "guard dodge", "hops its own" ],
      "architecture" => [ "TOCTOU", "the net that actually prevents", "only bites once", "load-bearing" ],
      "background-jobs" => [ "queue backs up", "outgrow", "graduation path", "Graduation to" ]
    }
  end

  it "keeps the retired phrases out" do
    found = retired.flat_map do |page, phrases|
      text = docs.join("#{page}.md").read
      phrases.select { |phrase| text.include?(phrase) }.map { |phrase| "#{page}: #{phrase}" }
    end

    expect(found).to be_empty, "retired phrases are back: #{found.join('; ')}"
  end

  it "names the switches a team setup turns on, where it used to say every switch" do
    intro = docs.join("how-code-ships.md").read[/^This page shows a team setup.*?\n\n/m]

    %w[AUTO_RELEASE DEPLOY_STAGING DEPLOY_PRODUCTION].each { |switch| expect(intro).to include(switch) }
  end

  it "says how to tell a release is named, in step 5's changelog rule" do
    expect(docs.join("how-code-ships.md").read).to include("has a <code>## v2026.11.18</code> heading")
  end

  it "glosses the release metaphor with the git word beside each image" do
    metaphor = docs.join("releasing.md").read[/^Every PR is a story\..*?\n\n/m]

    expect(metaphor).to include("(`next`)", "(the release branch)")
  end
end
