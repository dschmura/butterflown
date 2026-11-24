# frozen_string_literal: true

require "rails_helper"

RSpec.describe "the recipe for a job that emails a workspace's members" do
  let(:docs) { Rails.root.join("app/docs/developer") }
  let(:recipe) { docs.join("background-jobs.md").read[/^## A job that emails a workspace's members\n.*?(?=^## )/m] }

  it "sends through a notifier whose recipients block reads the workspace's kept memberships" do
    expect(recipe).to include("< ApplicationNotifier", "recipients do", "permitted_in_app(", "memberships.kept", ".deliver(nil)")
  end

  it "calls only what ApplicationNotifier and Membership really provide" do
    expect(ApplicationNotifier.method_defined?(:permitted_in_app) || ApplicationNotifier.private_method_defined?(:permitted_in_app)).to be(true)
    expect(Membership).to respond_to(:kept)
    expect(NotificationMailer._process_action_callbacks.map(&:filter)).to include(:abort_when_recipient_suspended)
  end

  it "is linked from Extending's jobs section and from Common Tasks" do
    anchor = "](/docs/developer/background-jobs#a-job-that-emails-a-workspaces-members)"

    expect(docs.join("extending.md").read).to include(anchor)
    expect(docs.join("common-tasks.md").read).to include(anchor)
  end
end
