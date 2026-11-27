require "rails_helper"

RSpec.describe Workspace, type: :model do
  describe "default member preset" do
    it "starts new communities on contributor" do
      expect(create(:workspace).default_member_preset).to eq("contributor")
    end

    it "accepts each of the three presets" do
      %w[contributor participant reader].each do |preset|
        expect(build(:workspace, default_member_preset: preset)).to be_valid
      end
    end

    it "rejects anything else in the model" do
      expect(build(:workspace, default_member_preset: "guest")).not_to be_valid
    end

    it "rejects anything else in the database" do
      workspace = create(:workspace)

      expect { Workspace.where(id: workspace.id).update_all(default_member_preset: "guest") }
        .to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint failed/)
    end
  end
end
