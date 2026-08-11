class AddRawActivationPayloadToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :raw_activation_payload, :jsonb, null: false, default: {}
  end
end
