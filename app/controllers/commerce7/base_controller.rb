module Commerce7
  # Base for Commerce7 server-to-server POSTs: the app-wide Install/Uninstall
  # URLs (activation, deactivation) and, per Commerce7::WebhooksController,
  # its per-tenant Web Hooks feature. Not browser requests, so this skips the
  # CSRF check and doesn't inherit ApplicationController's allow_browser
  # restriction.
  #
  # Auth is HTTP Basic in both cases, per Commerce7's docs: Install/Uninstall
  # URLs support an optional username/password configured in their
  # dashboard's "Advanced" section, and a Web Hook registered in the same
  # Developer Center app version (Step 1. APIs & Webhooks) supports the
  # same "Advanced Authentication" — both are a single app-wide credential
  # pair we set once, not something each tenant configures.
  class BaseController < ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false

    before_action :authenticate_commerce7!

    rescue_from ActionController::ParameterMissing do |error|
      render json: { error: error.message }, status: :bad_request
    end

    private

    def authenticate_commerce7!
      authenticate_or_request_with_http_basic do |username, password|
        expected_username = Rails.application.credentials.dig(:commerce7, :webhook_username)
        expected_password = Rails.application.credentials.dig(:commerce7, :webhook_password)

        expected_username.present? && expected_password.present? &&
          ActiveSupport::SecurityUtils.secure_compare(username, expected_username) &&
          ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
      end
    end
  end
end
