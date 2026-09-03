module Commerce7
  # Settings tab App Extension page (registered in Commerce7's Developer
  # Center as the app's "Settings tab iFrame URL", distinct from the
  # one-time install-form Client Settings and from the Report/Order-Detail
  # extension pages). Lets staff assign a color per club tier, persisted on
  # Tenant#tier_color_overrides. This is the app's first mutating,
  # browser-submitted form.
  class SettingsController < ExtensionController
    # Commerce7 iframes this page cross-site inside its admin panel; the
    # session cookie Rails' default CSRF token relies on may not persist in
    # that context (SameSite=Lax cookies aren't sent on cross-site non-GET
    # requests, and Safari ITP blocks third-party iframe cookies by
    # default). authenticate_staff! already re-validates a live
    # Commerce7-issued staff JWT (params[:account]) on every request, GET
    # or PATCH — unlike a session cookie, that's not an ambient credential
    # a forged page could attach automatically — so it's the real
    # authorization boundary for this write, not the session-based token.
    skip_before_action :verify_authenticity_token, only: :update

    def show
      @tiers = current_tiers
      @tier_colors = ClubMember.tier_colors(@tiers)
    end

    def update
      @tiers = current_tiers
      submitted = params.fetch(:tier_colors, {}).to_unsafe_h.slice(*@tiers)
      invalid = submitted.reject { |_tier, hex| hex.blank? || hex.match?(/\A#[0-9a-fA-F]{6}\z/) }

      if invalid.any?
        @tier_colors = ClubMember.tier_colors(@tiers).merge(submitted)
        @error = "Enter a valid hex color (e.g. #ff0000) for: #{invalid.keys.join(', ')}."
        render :show, status: :unprocessable_entity
        return
      end

      cleared, set = submitted.partition { |_tier, hex| hex.blank? }.map(&:to_h)
      Current.tenant.update!(tier_color_overrides: Current.tenant.tier_color_overrides.merge(set).except(*cleared.keys))

      redirect_to commerce7_settings_path(tenantId: params[:tenantId], account: params[:account], saved: true)
    end

    private

    def current_tiers
      ClubMember.tier_breakdown.keys.compact_blank.sort
    end
  end
end
