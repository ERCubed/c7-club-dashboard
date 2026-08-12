module Commerce7
  # Base for Commerce7 webhook receivers (activation, deactivation). These are
  # server-to-server POSTs, not browser requests, so this skips the CSRF check
  # and doesn't inherit ApplicationController's allow_browser restriction.
  #
  # Auth is HTTP Basic, per Commerce7's docs: install/uninstall URLs support an
  # optional username/password configured in their dashboard's "Advanced" section.
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
