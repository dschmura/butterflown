# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectMembershipChangedNotifier, type: :notifier do
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  def editor_on(project, user)
    ProjectMembership.create!(project: project, user: user, role: "editor")
  end

  def member_with_project_membership
    workspace = create(:workspace)
    user = create(:user)
    add_member(workspace, user: user)
    project = create(:project, workspace: workspace)
    [ user, project, editor_on(project, user) ]
  end

  describe ".category" do
    it "is :project_activity" do
      expect(described_class.category_name).to eq "project_activity"
    end
  end

  describe "dispatching" do
    it "delivers to the project membership's user and creates a Noticed::Notification row" do
      workspace = create(:workspace)
      user = create(:user)
      add_member(workspace, user: user)
      project = create(:project, workspace: workspace)
      pm = ProjectMembership.new(project: project, user: user, role: "editor")
      pm.save(validate: true)
      # Re-using the same record + same minute would dedup; bypass that for the
      # explicit-deliver assertion by advancing the idempotency-bucket clock.
      travel_to(2.minutes.from_now) do
        result = described_class.with(record: pm).deliver(user)
        expect(result).to eq :delivered
      end
      # The after_create_commit on PM also fires the notifier once, so the user
      # has exactly 2 notifications (one auto, one explicit).
      expect(user.notifications.count).to eq 2
    end

    it "auto-populates idempotency_key on the event column" do
      user, _project, project_membership = member_with_project_membership
      described_class.with(record: project_membership).deliver(user)
      event = Noticed::Event.last
      expect(event.idempotency_key).to be_present
      expect(event.params["idempotency_key"]).to be_nil
    end

    it "deduplicates concurrent dispatches within the same minute" do
      user, _project, project_membership = member_with_project_membership
      freeze_time do
        described_class.with(record: project_membership).deliver(user)
        result = described_class.with(record: project_membership).deliver(user)
        expect(result).to eq :deduplicated
      end
    end

    it "does not enqueue any NotificationMailer email job (in-app + digest only)" do
      user, _project, project_membership = member_with_project_membership
      expect {
        described_class.with(record: project_membership).deliver(user)
        drain_noticed_jobs
      }.not_to have_enqueued_mail
    end
  end

  describe "preferences gating" do
    it "respects DND (quiet hours active) for project_activity (does NOT bypass)" do
      workspace = create(:workspace)
      user = create(:user)
      add_member(workspace, user: user)
      prefs = create(:user_preferences, user: user)
      project = create(:project, workspace: workspace)
      project_membership = editor_on(project, user)
      # v2: DND is now time-windowed via quiet_hours. Set an always-active
      # window (00:00..23:59) to model the v1 "DND on" semantic.
      prefs.update!(notification_preferences:
        prefs.notification_preferences.merge(
          "quiet_hours" => { "enabled" => true, "start" => "00:00", "end" => "23:59", "allow_urgent" => true }
        ))
      described_class.with(record: project_membership).deliver(user)
      notification = user.notifications.last
      expect(notification.recipient_pref(:in_app)).to be false
      expect(notification.recipient_pref(:email)).to be false
    end

    it "permits in-app + email (instant) under default preferences (project_activity)" do
      workspace = create(:workspace)
      user = create(:user)
      add_member(workspace, user: user)
      prefs = create(:user_preferences, user: user)
      project = create(:project, workspace: workspace)
      project_membership = editor_on(project, user)
      # v2: defaults have email.frequency = "instant", so emails fire
      # immediately rather than queuing for digest.
      described_class.with(record: project_membership).deliver(user)
      notification = user.notifications.last
      expect(notification.recipient_pref(:in_app)).to be true
      expect(notification.recipient_pref(:email)).to be true
    end
  end

  describe "#message" do
    it "renders the localized project membership changed message" do
      user, project, project_membership = member_with_project_membership
      described_class.with(record: project_membership).deliver(user)
      notification = user.notifications.last
      expect(notification.message).to eq(
        I18n.t("notifications.project_membership_changed.message",
               project_name: project.name,
               new_role: "Editor")
      )
    end

    it "passes recipient_locale to I18n.t (matches the convention used by sibling notifiers)" do
      user, _project, project_membership = member_with_project_membership
      # The message must forward `locale: recipient_locale` to I18n.t,
      # not rely on the ambient locale at dispatch time.
      with_available_locale(:fr, notifications: { project_membership_changed: { message: "FR %{project} %{new_role}" } }) do
        prefs = create(:user_preferences, user: user)
        prefs.update!(locale: "fr")
        described_class.with(record: project_membership).deliver(user)
        notification = user.notifications.last
        expect(I18n).to receive(:t).with(
          "notifications.project_membership_changed.message",
          hash_including(locale: :fr)
        ).and_call_original
        notification.message
      end
    end
  end

  describe "ProjectMembership callback triggers" do
    it "fires on after_create_commit when a user is added to a project" do
      workspace = create(:workspace)
      user = create(:user)
      add_member(workspace, user: user)
      another_user = create(:user)
      add_member(workspace, user: another_user)
      project = create(:project, workspace: workspace)
      expect {
        ProjectMembership.create!(project: project, user: another_user, role: "viewer")
      }.to change { Noticed::Event.where(type: described_class.name).count }.by(1)
      expect(another_user.notifications.count).to eq 1
    end

    it "fires on after_update_commit when role changes on a project membership" do
      # Create the PM in one minute bucket, then update in the next so the
      # idempotency_key differs and the second dispatch isn't deduplicated.
      workspace = create(:workspace)
      user = create(:user)
      add_member(workspace, user: user)
      pm = nil
      travel_to(2.minutes.ago) do
        pm = editor_on(create(:project, workspace: workspace), user)
      end
      expect {
        pm.update!(role: "viewer")
      }.to change { Noticed::Event.where(type: described_class.name).count }.by(1)
    end

    it "does not fire on unrelated updates" do
      _user, _project, project_membership = member_with_project_membership
      expect {
        project_membership.update!(pinned: true)
      }.not_to change { Noticed::Event.where(type: described_class.name).count }
    end
  end

  # #919 exposed this: no in-app surface rendered a notifier url before, and
  # this one called a route helper that never existed.
  describe "#url" do
    it "points at the project under its workspace" do
      user, project, project_membership = member_with_project_membership
      described_class.with(record: project_membership).deliver(user)
      notification = user.notifications.order(:id).last

      expect(notification.url).to eq(
        Rails.application.routes.url_helpers.workspace_project_path(project.workspace, project)
      )
    end
  end
  # #920. The row outlives the workspace it points at, and #url may not raise
  # out of the notifications index or the digest render — the digest wraps
  # RENDERING, not URL generation, so one stale row takes down a whole
  # recipient's digest rather than just its own line.
  describe "#url once the workspace is gone" do
    it "renders the placeholder instead of raising" do
      user, project, _project_membership = member_with_project_membership
      workspace = project.workspace
      notification = Noticed::Event.where(type: described_class.name).last.notifications.first
      workspace.destroy!

      expect(notification.reload.url).to eq(I18n.t("notifications.placeholder"))
    end
  end
end
