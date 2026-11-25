class AllowNullClientAccessCompanyName < ActiveRecord::Migration[8.1]
  # The app stops writing company_name; a later migration drops it from both tables.
  def change
    change_column_null :client_accesses, :company_name, true
  end
end
