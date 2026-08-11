class CreateOrderSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :order_summaries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :commerce7_customer_id, null: false
      t.datetime :last_order_at
      t.decimal :lifetime_value, precision: 12, scale: 2, null: false, default: 0
      t.integer :order_count, null: false, default: 0

      t.timestamps
    end
    add_index :order_summaries, [ :tenant_id, :commerce7_customer_id ], unique: true
    add_index :order_summaries, [ :tenant_id, :last_order_at ]
  end
end
