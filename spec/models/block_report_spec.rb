require "rails_helper"

RSpec.describe BlockReport, type: :model do
  let(:community) { create(:workspace, max_members: 20) }
  let(:admin) { create(:membership, :admin, workspace: community).user }
  let(:blocker) { create(:membership, workspace: community).user }
  let(:blocked) { create(:membership, workspace: community).user }
  let!(:block) { Block.create!(workspace: community, blocker: blocker, blocked: blocked) }

  def report(reason: "harassment", note: "Messages after I asked them to stop", from: block)
    from.report!(reason: reason, note: note)
  end

  it "is made from a block, naming who blocked whom" do
    expect(report).to have_attributes(workspace: community, reporter: blocker, reported: blocked, reason: "harassment")
  end

  it "takes one of the four reasons" do
    %w[harassment unwanted_contact something_they_posted other].each do |reason|
      BlockReport.delete_all

      expect(report(reason: reason)).to be_persisted
    end
    expect { report(reason: "spite") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "keeps the note optional, and encrypted at rest" do
    record = report

    expect(report(note: nil, from: Block.create!(workspace: community, blocker: blocked, blocked: blocker))).to be_persisted
    raw = BlockReport.connection.select_value("SELECT note FROM block_reports WHERE id = #{record.id}")
    expect(raw).not_to include("asked them")
  end

  it "stays when the block is lifted, since the admins were told" do
    record = report

    block.destroy!

    expect(record.reload).to be_persisted
  end

  it "is handled around an admin with a block involving either of them" do
    sage = create(:membership, :admin, workspace: community).user
    Block.create!(workspace: community, blocker: blocked, blocked: admin)

    expect(report.handlers).to contain_exactly(sage)
  end

  it "resolves once, and logs it where only admins read it" do
    record = report
    record.resolve!(by: admin)

    expect(record.reload).to have_attributes(open?: false, resolved_by: admin)
    expect(ActivityLog.find_by!(action: "block_report.resolved")).to have_attributes(visibility: "admin")
    expect { record.resolve!(by: admin) }.to raise_error(BlockReport::AlreadyResolved)
  end

  it "keeps the block silent until reported: no activity row for blocking" do
    expect(ActivityLog.where(action: [ "block.created", "block_report.created" ])).to be_empty
  end
end
