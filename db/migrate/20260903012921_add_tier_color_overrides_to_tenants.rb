class AddTierColorOverridesToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :tier_color_overrides, :jsonb, null: false, default: {}
  end
end
