class RemoveApiCredentialsFromTenants < ActiveRecord::Migration[8.1]
  def change
    remove_column :tenants, :api_key, :string
    remove_column :tenants, :api_secret, :string
  end
end
