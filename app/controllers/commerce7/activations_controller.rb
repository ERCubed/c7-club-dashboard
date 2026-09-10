module Commerce7
  # Receives Commerce7's activation POST on app install. Per Commerce7's docs,
  # this sends `tenantId` plus the installer's first name, last name, and
  # email — NOT API credentials. That's expected: the App ID/Secret Key is a
  # single app-wide pair (Rails credentials, see Commerce7::Client), not
  # something issued per tenant.
  class ActivationsController < BaseController
    def create
      tenant = Tenant.activate!(commerce7_tenant_id: params.require(:tenantId), payload: activation_payload)

      # Backfill: Commerce7's Web Hooks (see WebhooksController) only fire on
      # future changes, not a newly (re)installed tenant's pre-existing club
      # memberships — this one-time sync is what actually populates those.
      Commerce7::SyncJob.perform_later(tenant)

      AuditEvent.record!(event_type: "tenant_activated", success: true, commerce7_tenant_id: tenant.commerce7_tenant_id, origin_ip: request.remote_ip)

      head :ok
    end

    private

    def activation_payload
      params.except(:controller, :action).to_unsafe_h
    end
  end
end
