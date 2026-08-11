module Commerce7
  # Base for Commerce7 webhook receivers (activation, deactivation). These are
  # server-to-server POSTs, not browser requests, so this skips the CSRF check
  # and doesn't inherit ApplicationController's allow_browser restriction.
  class BaseController < ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false

    before_action :authenticate_commerce7!

    rescue_from ActionController::ParameterMissing do |error|
      render json: { error: error.message }, status: :bad_request
    end

    private

    def authenticate_commerce7!
      token = Rails.application.credentials.dig(:commerce7, :webhook_token)
      return if token.present? && ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, token)

      head :unauthorized
    end
  end
end
