module Commerce7
  # Base for pages embedded as a Commerce7 App Extension (iframe). Commerce7
  # appends `tenantId` and `account` (a staff JWT) to the iframe src URL;
  # this validates that JWT against Commerce7's API and resolves
  # Current.tenant/Current.staff_user before any subclass action runs.
  class ExtensionController < ApplicationController
    before_action :authenticate_staff!

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
