class RemoveCompanyNameFromClientInvites < ActiveRecord::Migration[8.1]
  # Ships a release after the code that ignores the column, so no running server still writes it.
  def change
    remove_column :invitations, :company_name, :string
    remove_column :client_accesses, :company_name, :string
  end
end
