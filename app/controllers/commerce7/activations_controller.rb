module Commerce7
  # Receives Commerce7's activation POST on app install. Per Commerce7's docs,
  # this sends `tenantId` plus the installer's first name, last name, and
  # email — NOT API credentials. How this app is meant to obtain a tenant's
  # API credentials (a single app-wide App ID/Secret Key vs. something
  # per-tenant) is still unresolved; `Tenant#api_key`/`api_secret` are left
  # untouched here until that's confirmed.
  class ActivationsController < BaseController
    def create
      tenant = Tenant.find_or_initialize_by(commerce7_tenant_id: params.require(:tenantId))
      tenant.assign_attributes(
        activated_at: Time.current,
        deactivated_at: nil,
        raw_activation_payload: activation_payload
      )
      tenant.save!

      head :ok
    end

    private

    def activation_payload
      params.except(:controller, :action).to_unsafe_h
    end
  end
end
