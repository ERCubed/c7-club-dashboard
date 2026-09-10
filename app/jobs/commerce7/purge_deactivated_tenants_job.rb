module Commerce7
  # Recurring job (see config/recurring.yml) enforcing Commerce7's app
  # security policy: customer data deleted within 30 days of app
  # termination. Hard-deletes any Tenant still deactivated past
  # Tenant::DATA_RETENTION_DAYS, cascading (dependent: :destroy) to its
  # ClubMember and OrderSummary rows.
  class PurgeDeactivatedTenantsJob < ApplicationJob
    queue_as :default

    def perform
      Tenant.pending_deletion.find_each { |tenant| purge(tenant) }
    end

    private

    # ClubMember/OrderSummary's TenantScoped default_scope resolves to `none`
    # without Current.tenant set — which `dependent: :destroy` relies on via
    # the tenant.club_members/order_summaries associations. Skipping this
    # doesn't just leave those rows behind: it makes the tenant DELETE itself
    # fail outright, since club_members/order_summaries have a real FK
    # constraint back to tenants with no ON DELETE CASCADE (confirmed by
    # reproducing the ActiveRecord::InvalidForeignKey before adding this).
    def purge(tenant)
      commerce7_tenant_id = tenant.commerce7_tenant_id
      Current.tenant = tenant
      tenant.destroy!
      AuditEvent.record!(event_type: "tenant_data_purged", success: true, commerce7_tenant_id: commerce7_tenant_id)
    ensure
      Current.tenant = nil
    end
  end
end
