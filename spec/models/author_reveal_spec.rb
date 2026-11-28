require "rails_helper"

RSpec.describe AuthorReveal, type: :model do
  let(:community) { create(:workspace, max_members: 20, anonymous_posting: true) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:author) { create(:membership, workspace: community).user }
  let(:anonymous) { create(:memory, workspace: community, author: author, visibility: "community", anonymous: true) }

  it "tells the admin who wrote an anonymous memory" do
    expect(anonymous.reveal_author_to!(admin, reason: "Threats in the text")).to eq(author)
  end

  it "logs who revealed it, when, and which memory, where only admins read it, without the reason" do
    anonymous.reveal_author_to!(admin, reason: "Threats in the text")

    entry = ActivityLog.find_by!(action: "author_reveal.created")
    expect(entry).to have_attributes(visibility: "admin", workspace_id: community.id)
    expect(entry.metadata).to eq("revealed_by" => admin.id, "memory_id" => anonymous.id)
  end

  it "keeps the reason, encrypted at rest" do
    anonymous.reveal_author_to!(admin, reason: "Threats in the text")
    reveal = AuthorReveal.sole

    expect(reveal.reason).to eq("Threats in the text")
    raw = AuthorReveal.connection.select_value("SELECT reason FROM author_reveals WHERE id = #{reveal.id}")
    expect(raw).not_to include("Threats")
  end

  it "needs a reason" do
    expect { anonymous.reveal_author_to!(admin, reason: " ") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "has nothing to reveal on a memory with its author's name on it" do
    named = create(:memory, workspace: community, author: author, visibility: "community")

    expect { named.reveal_author_to!(admin, reason: "x") }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
