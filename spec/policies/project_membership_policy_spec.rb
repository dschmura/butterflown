require "rails_helper"

RSpec.describe ProjectMembershipPolicy do
  def project_with_creator
    workspace = create(:workspace)
    Current.workspace = workspace
    creator = create(:user)
    create(:membership, :owner, user: creator, workspace: workspace)
    create(:project, workspace: workspace, created_by: creator)
  end

  def editor_membership_on(project)
    editor = create(:user)
    create(:membership, user: editor, workspace: project.workspace)
    create(:project_membership, project: project, user: editor)
  end

  describe "for project creator" do
    it "allows create" do
      project = project_with_creator
      editor_pm = editor_membership_on(project)

      expect(described_class.new(project.created_by, editor_pm).create?).to be true
    end

    it "allows update on editor" do
      project = project_with_creator
      editor_pm = editor_membership_on(project)

      expect(described_class.new(project.created_by, editor_pm).update?).to be true
    end

    it "allows destroy on editor" do
      project = project_with_creator
      editor_pm = editor_membership_on(project)

      expect(described_class.new(project.created_by, editor_pm).destroy?).to be true
    end

    it "denies destroying creator membership" do
      project = project_with_creator
      creator = project.created_by
      editor_membership_on(project)
      creator_pm = project.project_memberships.find_by(user: creator)

      expect(described_class.new(creator, creator_pm).destroy?).to be false
    end
  end

  describe "for project editor" do
    it "denies create" do
      project = project_with_creator
      editor_pm = editor_membership_on(project)

      expect(described_class.new(editor_pm.user, editor_pm).create?).to be false
    end

    it "allows pin on own membership" do
      project = project_with_creator
      editor_pm = editor_membership_on(project)

      expect(described_class.new(editor_pm.user, editor_pm).pin?).to be true
    end

    it "denies pin on others' membership" do
      project = project_with_creator
      editor_pm = editor_membership_on(project)
      creator_pm = project.project_memberships.find_by(user: project.created_by)

      expect(described_class.new(editor_pm.user, creator_pm).pin?).to be false
    end
  end

  # The `project` resolver has two branches: read the record's own project when
  # the record carries one, else fall back to Current.project. index? authorizes
  # against the class (no instance), so it exercises the fallback branch.
  describe "index? when the record is the class (Current.project fallback)" do
    it "allows a project member" do
      project = project_with_creator
      Current.project = project

      expect(described_class.new(project.created_by, ProjectMembership).index?).to be true
    end

    it "denies a workspace member who is not on the project" do
      project = project_with_creator
      editor_membership_on(project)
      Current.project = project
      outsider = create(:user)
      create(:membership, user: outsider, workspace: project.workspace)

      expect(described_class.new(outsider, ProjectMembership).index?).to be false
    end
  end
end
