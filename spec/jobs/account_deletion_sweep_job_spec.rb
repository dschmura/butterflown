require "rails_helper"

RSpec.describe AccountDeletionSweepJob, type: :job do
  it "deletes the accounts whose 30 days are up, and leaves the rest pending" do
    due = create(:user).tap(&:request_deletion!)
    later = create(:user)
    travel(10.days) { later.request_deletion! }

    travel(30.days + 1.minute) { described_class.perform_now }

    expect([ due.reload, later.reload ].map(&:deleted?)).to eq([ true, false ])
  end

  it "carries on past an account it can't delete yet, and leaves that one pending" do
    stuck = create(:user).tap(&:request_deletion!)
    owned = create(:workspace)
    create(:membership, :owner, workspace: owned, user: stuck)
    other = create(:user).tap(&:request_deletion!)

    travel(30.days + 1.minute) { described_class.perform_now }

    expect(stuck.reload).to have_attributes(deleted?: false, deletion_pending?: true)
    expect(other.reload.deleted?).to be(true)
  end
end
