class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :commerce7_tenant_id, null: false
      t.string :name
      t.string :api_key
      t.string :api_secret
      t.datetime :activated_at
      t.datetime :deactivated_at

      t.timestamps
    end
    add_index :tenants, :commerce7_tenant_id, unique: true
  end
end
