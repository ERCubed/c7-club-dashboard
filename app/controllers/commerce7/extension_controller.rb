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
      unless tenant
        audit_auth!(success: false, tenant_id: tenant_id, reason: "unknown_or_deactivated_tenant")
        return head :forbidden
      end

      Current.staff_user = Commerce7::AccountClient.new.fetch_user(tenant_id: tenant_id, token: params.require(:account))
      Current.tenant = tenant
      audit_auth!(success: true, tenant_id: tenant_id, actor: Current.staff_user["email"])
    rescue Commerce7::AccountClient::AuthenticationError
      audit_auth!(success: false, tenant_id: tenant_id, reason: "invalid_staff_token")
      render "commerce7/extension/unauthorized", status: :unauthorized
    end

    def audit_auth!(success:, tenant_id:, actor: nil, reason: nil)
      AuditEvent.record!(
        event_type: "staff_extension_auth",
        success: success,
        actor: actor,
        commerce7_tenant_id: tenant_id,
        origin_ip: request.remote_ip,
        metadata: reason ? { reason: reason } : {}
      )
    end
  end
end
