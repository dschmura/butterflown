require "rails_helper"

RSpec.describe "Signing in while an account is pending deletion", type: :request do
  let(:user) { create(:user) }
  let!(:membership) { create(:membership, user: user) }

  it "cancels the deletion and brings them back to their communities" do
    user.request_deletion!

    post session_path, params: { email_address: user.email_address, password: "SecureP@ssw0rd123!" }

    expect(response).to redirect_to(root_path)
    expect(user.reload.deletion_pending?).to be(false)
    expect(membership.reload.kept?).to be(true)
  end
end
