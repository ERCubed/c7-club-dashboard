module Commerce7
  # Receives Commerce7's deactivation POST on app uninstall. Soft-deactivates
  # the tenant (never hard-deletes) so a reinstall can reactivate the same
  # record. A tenantId we don't recognize is a no-op, not an error, since
  # webhook retries are common and shouldn't fail loudly.
  class DeactivationsController < BaseController
    def create
      tenant = Tenant.find_by(commerce7_tenant_id: params.require(:tenantId))
      tenant&.update!(deactivated_at: Time.current)

      head :ok
    end
  end
end
