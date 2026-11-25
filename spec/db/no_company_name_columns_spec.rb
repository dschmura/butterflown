# frozen_string_literal: true

require "rails_helper"

RSpec.describe "client company names" do
  it "are not stored on invitations or client accesses" do
    %i[invitations client_accesses].each do |table|
      expect(ActiveRecord::Base.connection.column_exists?(table, :company_name)).to be(false), "#{table}.company_name still exists"
    end
  end
end
