require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "preset" do
    it "starts a new member on the community's default preset" do
      workspace = create(:workspace, default_member_preset: "participant")

      membership = create(:membership, workspace: workspace)

      expect(membership.preset).to eq("participant")
    end

    it "keeps a preset chosen when the membership is created" do
      workspace = create(:workspace, default_member_preset: "participant")

      membership = create(:membership, workspace: workspace, preset: "reader")

      expect(membership.preset).to eq("reader")
    end

    it "keeps an explicit choice that happens to match the column's default" do
      workspace = create(:workspace, default_member_preset: "participant")

      membership = create(:membership, workspace: workspace, preset: "contributor")

      expect(membership.preset).to eq("contributor")
    end

    it "starts someone admitted to the community on its default" do
      workspace = create(:workspace, default_member_preset: "reader")

      membership = workspace.admit(create(:user), role: Role.system_default!("member"))

      expect(membership.preset).to eq("reader")
    end

    it "is contributor in a community that never chose a default" do
      expect(create(:membership).preset).to eq("contributor")
    end

    it "rejects a preset outside the three, in the model" do
      membership = build(:membership, preset: "moderator")

      expect(membership).not_to be_valid
      expect(membership.errors).to be_added(:preset, :inclusion, value: "moderator")
    end

    it "rejects a preset outside the three, in the database" do
      membership = create(:membership)

      expect { Membership.where(id: membership.id).update_all(preset: "moderator") }
        .to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
    end
  end

  describe "what each preset may do" do
    let(:workspace) { create(:workspace) }

    def member(preset)
      create(:membership, workspace: workspace, preset: preset)
    end

    it "lets a contributor post, reflect, comment, tag, collect and suggest" do
      expect(member("contributor")).to have_attributes(
        may_post_memories?: true, may_reflect?: true, may_comment?: true,
        may_tag?: true, may_create_collections?: true, may_suggest_invites?: true
      )
    end

    it "lets a participant join in on others' memories but not post or collect" do
      expect(member("participant")).to have_attributes(
        may_post_memories?: false, may_reflect?: true, may_comment?: true,
        may_tag?: true, may_create_collections?: false, may_suggest_invites?: true
      )
    end

    it "lets a reader only read" do
      expect(member("reader")).to have_attributes(
        may_post_memories?: false, may_reflect?: false, may_comment?: false,
        may_tag?: false, may_create_collections?: false, may_suggest_invites?: false
      )
    end

    it "gives a guest nothing, whatever preset their row carries" do
      guest = create(:membership, :viewer, workspace: workspace, preset: "contributor")

      expect(guest).to be_guest
      expect(guest).to have_attributes(
        may_post_memories?: false, may_reflect?: false, may_comment?: false,
        may_tag?: false, may_create_collections?: false, may_suggest_invites?: false
      )
    end

    it "gives admins and the owner everything a contributor has, whatever their row says" do
      admin = create(:membership, :admin, workspace: workspace, preset: "reader")
      owner = create(:membership, :owner, workspace: workspace, preset: "reader")

      [ admin, owner ].each do |membership|
        expect(membership).to have_attributes(
          may_post_memories?: true, may_reflect?: true, may_comment?: true,
          may_tag?: true, may_create_collections?: true, may_suggest_invites?: true
        )
      end
    end

    it "loses every permission once the membership is deactivated, admins included" do
      member = create(:membership, :deactivated, workspace: workspace, preset: "contributor")
      admin = create(:membership, :admin, :deactivated, workspace: workspace)

      [ member, admin ].each do |membership|
        expect(membership).to have_attributes(
          may_post_memories?: false, may_reflect?: false, may_comment?: false,
          may_tag?: false, may_create_collections?: false, may_suggest_invites?: false
        )
      end
    end

    it "does not call a member a guest" do
      expect(member("reader")).not_to be_guest
    end
  end

  describe "preset-change audit trail" do
    it "records the change by value and routes it to the admin feed" do
      workspace = create(:workspace)
      admin = create(:user)
      create(:membership, :admin, user: admin, workspace: workspace)
      target = create(:membership, workspace: workspace, preset: "contributor")
      Current.session = admin.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
      Current.workspace = workspace

      target.update!(preset: "reader")

      log = ActivityLog.where(trackable: target, action: "membership.updated").order(:id).last
      expect(log.actor).to eq(admin)
      expect(log.metadata["changes"]["preset"]).to eq([ "contributor", "reader" ])
      expect(log.visibility).to eq("admin")
    ensure
      Current.session = nil
      Current.workspace = nil
    end
  end
end
