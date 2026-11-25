require "rails_helper"

RSpec.describe ProjectPolicy do
  let(:workspace) { create(:workspace) }
  let(:creator_user) { create(:user) }
  let(:editor_user) { create(:user) }
  let(:non_member_user) { create(:user) }
  let(:project) { create(:project, workspace: workspace, created_by: creator_user) }

  before do
    Current.workspace = workspace
    create(:membership, :owner, user: creator_user, workspace: workspace)
    create(:membership, user: editor_user, workspace: workspace)
    create(:membership, user: non_member_user, workspace: workspace)
    create(:project_membership, project: project, user: editor_user)
  end

  describe "for project creator" do
    it "allows show" do
      expect(described_class.new(creator_user, project).show?).to be true
    end

    it "allows update" do
      expect(described_class.new(creator_user, project).update?).to be true
    end

    it "allows destroy" do
      expect(described_class.new(creator_user, project).destroy?).to be true
    end

    it "allows archive and unarchive" do
      expect(described_class.new(creator_user, project).archive?).to be true
      expect(described_class.new(creator_user, project).unarchive?).to be true
    end
  end

  describe "for project editor" do
    it "allows show" do
      expect(described_class.new(editor_user, project).show?).to be true
    end

    it "denies update" do
      expect(described_class.new(editor_user, project).update?).to be false
    end

    it "denies destroy" do
      expect(described_class.new(editor_user, project).destroy?).to be false
    end

    it "denies archive and unarchive" do
      expect(described_class.new(editor_user, project).archive?).to be false
      expect(described_class.new(editor_user, project).unarchive?).to be false
    end
  end

  describe "for workspace member not in project" do
    it "allows index" do
      expect(described_class.new(non_member_user, project).index?).to be true
    end

    it "denies show" do
      expect(described_class.new(non_member_user, project).show?).to be false
    end

    it "allows create" do
      expect(described_class.new(non_member_user, project).create?).to be true
    end
  end

  describe "workspace owner (not project member) can destroy" do
    let(:owner_user) { create(:user) }
    before { create(:membership, :owner, user: owner_user, workspace: workspace) }

    it "allows destroy via manage_workspace permission" do
      expect(described_class.new(owner_user, project).destroy?).to be true
    end
  end

  describe "#manage_clientside?" do
    let(:member_creator) { create(:user) }
    let(:member_project) { create(:project, workspace: workspace, created_by: member_creator) }

    before { create(:membership, user: member_creator, workspace: workspace) }

    it "allows the project's creator whose workspace role cannot manage members" do
      expect(described_class.new(member_creator, member_project).manage_clientside?).to be true
    end

    it "allows an admin outside the project" do
      admin = create(:membership, :admin, workspace: workspace).user
      expect(described_class.new(admin, member_project).manage_clientside?).to be true
    end

    it "denies a project member who is not the creator" do
      expect(described_class.new(editor_user, project).manage_clientside?).to be false
    end

    it "denies a workspace member outside the project" do
      expect(described_class.new(non_member_user, project).manage_clientside?).to be false
    end
  end
end
