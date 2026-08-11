module Commerce7
  # Receives Commerce7's activation POST on app install: `tenantId` plus
  # "setup variables". Field names for credentials (assumed here as
  # `apiKey`/`apiSecret`, matching tenantId's camelCase) are unconfirmed —
  # verify against a real payload once sandbox access is available.
  class ActivationsController < BaseController
    def create
      tenant = Tenant.find_or_initialize_by(commerce7_tenant_id: params.require(:tenantId))
      tenant.assign_attributes(
        activated_at: Time.current,
        deactivated_at: nil,
        api_key: params[:apiKey].presence || tenant.api_key,
        api_secret: params[:apiSecret].presence || tenant.api_secret,
        raw_activation_payload: activation_payload
      )
      tenant.save!

      head :ok
    end

    private

    # Excludes apiKey/apiSecret: those are already stored encrypted on the
    # tenant, and this column is plain jsonb, not encrypted.
    def activation_payload
      params.except(:controller, :action, :token, :apiKey, :apiSecret).to_unsafe_h
    end
  end
end
