require "rails_helper"

RSpec.describe Memory, type: :model do
  it "accepts only the three audiences" do
    expect(build(:memory, visibility: "community")).to be_valid
    expect(build(:memory, visibility: "everyone")).not_to be_valid
  end

  it "accepts only viewers or the author for each rule" do
    %i[comment_rule reflect_rule tag_rule].each do |rule|
      expect(build(:memory, rule => "author")).to be_valid
      expect(build(:memory, rule => "anyone")).not_to be_valid, rule.to_s
    end
  end

  it "rejects an unknown audience in the database too" do
    memory = create(:memory)

    expect { Memory.where(id: memory.id).update_all(visibility: "everyone") }
      .to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
  end

  it "leaves no trace in the community's activity feed" do
    workspace = create(:workspace)
    author = create(:membership, workspace: workspace).user
    resources = [ { kind: "written_reflection", body: "Kept to myself." } ]

    expect { workspace.post_memory(author: author, resources: resources) }.not_to change(ActivityLog, :count)
    expect(workspace.memories.count).to eq(1)
  end

  it "keeps its author's account from being deleted out from under it" do
    memory = create(:memory)

    expect { User.where(id: memory.author_id).delete_all }.to raise_error(ActiveRecord::InvalidForeignKey)
    expect(memory.reload.author).to be_present
  end

  it "takes its resources with it when destroyed" do
    memory = create(:memory)

    expect { memory.destroy! }.to change(MemoryResource, :count).by(-1)
  end
end
