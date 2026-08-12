class ChangeLifetimeValueToCentsOnOrderSummaries < ActiveRecord::Migration[8.1]
  def change
    # Commerce7 returns order amounts in integer cents. Storing decimal
    # dollars invited a scaling bug the first time the sync job wrote to it.
    remove_column :order_summaries, :lifetime_value, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :order_summaries, :lifetime_value_cents, :bigint, null: false, default: 0
  end
end
