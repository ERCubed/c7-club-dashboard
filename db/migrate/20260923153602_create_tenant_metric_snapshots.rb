class CreateTenantMetricSnapshots < ActiveRecord::Migration[8.1]
  def change
    # One row per tenant per day (see Commerce7::SnapshotMetricsJob) — ClubMember/
    # OrderSummary only ever hold current state, so this is what lets the
    # dashboard chart trends over time at all.
    create_table :tenant_metric_snapshots do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :snapshot_date, null: false
      t.integer :active_members_count, null: false, default: 0
      t.bigint :revenue_cents, null: false, default: 0
      t.integer :at_risk_count, null: false, default: 0

      t.timestamps
    end

    add_index :tenant_metric_snapshots, [ :tenant_id, :snapshot_date ], unique: true
  end
end
