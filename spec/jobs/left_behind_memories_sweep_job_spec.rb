require "rails_helper"

RSpec.describe LeftBehindMemoriesSweepJob, type: :job do
  it "purges private memories whose author left more than 90 days ago" do
    membership = create(:membership)
    gone = create(:memory, workspace: membership.workspace, author: membership.user, visibility: "only_me")
    membership.leave!

    travel(90.days + 1.minute) { described_class.perform_now }

    expect(Memory.exists?(gone.id)).to be(false)
  end
end
