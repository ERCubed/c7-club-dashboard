module Commerce7
  # Base for pages embedded as a Commerce7 App Extension (iframe). Commerce7
  # appends `tenantId` and `account` (a staff JWT) to the iframe src URL;
  # this validates that JWT against Commerce7's API and resolves
  # Current.tenant/Current.staff_user before any subclass action runs.
  class ExtensionController < ApplicationController
    layout "commerce7_extension"

    before_action :authenticate_staff!

    # Rails sends X-Frame-Options: SAMEORIGIN by default, which blocks
    # Commerce7's admin panel (a different origin) from framing this page at
    # all. Commerce7's docs don't publish the exact admin origin to scope a
    # replacement CSP frame-ancestors to (see club-dashboard-plan.md open
    # questions), so for now this just drops the blanket deny; tighten to a
    # specific frame-ancestors once that origin is confirmed.
    after_action { response.headers.delete("X-Frame-Options") }

    rescue_from ActionController::ParameterMissing do |error|
      render plain: error.message, status: :bad_request
    end

    private

    def authenticate_staff!
      tenant_id = params.require(:tenantId)
      tenant = Tenant.active.find_by(commerce7_tenant_id: tenant_id)
      return head :forbidden unless tenant

      Current.staff_user = Commerce7::AccountClient.new.fetch_user(tenant_id: tenant_id, token: params.require(:account))
      Current.tenant = tenant
    rescue Commerce7::AccountClient::AuthenticationError
      head :unauthorized
    end
  end
end
