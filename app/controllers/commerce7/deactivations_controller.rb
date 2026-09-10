module Commerce7
  # Receives Commerce7's deactivation POST on app uninstall. Soft-deactivates
  # the tenant (never hard-deletes) so a reinstall can reactivate the same
  # record. A tenantId we don't recognize is a no-op, not an error, since
  # webhook retries are common and shouldn't fail loudly.
  class DeactivationsController < BaseController
    def create
      tenant = Tenant.find_by(commerce7_tenant_id: params.require(:tenantId))
      if tenant
        tenant.deactivate!
        AuditEvent.record!(event_type: "tenant_deactivated", success: true, commerce7_tenant_id: tenant.commerce7_tenant_id, origin_ip: request.remote_ip)
      end

      head :ok
    end
  end
end
