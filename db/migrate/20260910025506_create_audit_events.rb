class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    # No belongs_to :tenant FK deliberately: an audit trail must survive the
    # thing it's auditing (see Commerce7::PurgeDeactivatedTenantsJob, which
    # hard-deletes a Tenant 30 days after deactivation) and must also cover
    # events where no tenant was ever resolved (an auth failure against an
    # unrecognized tenantId is itself worth recording). A plain string
    # snapshot decouples audit history from Tenant's lifecycle entirely.
    create_table :audit_events do |t|
      t.string :event_type, null: false
      t.boolean :success, null: false
      t.string :actor
      t.string :commerce7_tenant_id
      t.string :origin_ip
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :audit_events, :created_at
    add_index :audit_events, :commerce7_tenant_id
    add_index :audit_events, :event_type
  end
end
