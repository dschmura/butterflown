# frozen_string_literal: true

require "rails_helper"
require_relative "../../db/migrate/20261125160000_add_client_to_invitations"

# Runs down then up inside the example's rollback, as the join-links migration spec does.
RSpec.describe AddClientToInvitations do
  let(:raw_invitations) { Class.new(ActiveRecord::Base) { self.table_name = "invitations" } }
  let(:migration) { described_class.new }
  let(:project) { create(:project) }
  let(:inviter) { create(:user) }

  before do
    ActiveRecord::Migration.suppress_messages { migration.down }
    # The backfill reads company_name, which a later migration drops.
    connection = ActiveRecord::Base.connection
    connection.add_column(:invitations, :company_name, :string) unless connection.column_exists?(:invitations, :company_name)
  end

  after do
    ActiveRecord::Base.connection.schema_cache.clear!
    Invitation.reset_column_information
  end

  def raw_invitation(company_name:, role_id:)
    raw_invitations.create!(
      invitable_type: "Project", invitable_id: project.id, invited_by_id: inviter.id,
      role_id: role_id, company_name: company_name, token: SecureRandom.hex,
      status: "pending", expires_at: 7.days.from_now
    )
  end

  it "flags the invitations that carried a company name, then reverses" do
    client = raw_invitation(company_name: "ciphertext", role_id: nil)
    member = raw_invitation(company_name: nil, role_id: Role.system_default!("member").id)

    ActiveRecord::Migration.suppress_messages { migration.up }
    raw_invitations.reset_column_information

    expect(raw_invitations.find(client.id).client).to be(true)
    expect(raw_invitations.find(member.id).client).to be(false)
    expect(ActiveRecord::Base.connection.columns("invitations").find { _1.name == "client" }.null).to be(false)

    ActiveRecord::Migration.suppress_messages { migration.down }

    expect(ActiveRecord::Base.connection.columns("invitations").map(&:name)).not_to include("client")
  end
end
