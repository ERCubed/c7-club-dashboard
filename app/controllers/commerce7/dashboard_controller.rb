module Commerce7
  # Reports > Club Report App Extension page. Reads the data Commerce7::SyncJob
  # already synced into ClubMember/OrderSummary — this controller never calls
  # Commerce7's API itself.
  class DashboardController < ExtensionController
    layout "commerce7_extension"

    def show
      @at_risk_months = at_risk_months
      @tier_breakdown = ClubMember.tier_breakdown
      @tier_colors = ClubMember.tier_colors(@tier_breakdown.keys)
      @top_spenders = ClubMember.top_spenders
      @revenue_by_tier = ClubMember.revenue_by_tier
      @new_members_this_month = ClubMember.new_this_month.count
      @average_order_value_cents = ClubMember.average_order_value_cents

      at_risk_scope = ClubMember.at_risk(@at_risk_months)
      @at_risk_count = at_risk_scope.count
      @at_risk_members = at_risk_scope.includes(:order_summary)
        .order(Arel.sql("order_summaries.last_order_at ASC NULLS FIRST")).limit(50)

      @trend_days = trend_days
      @trend_snapshots = TenantMetricSnapshot.recent(@trend_days)
    end

    private

    DEFAULT_TREND_DAYS = 90

    def at_risk_months
      months = params[:at_risk_months].to_i
      months.positive? ? months : ClubMember::DEFAULT_AT_RISK_MONTHS
    end

    def trend_days
      days = params[:trend_days].to_i
      days.positive? ? days : DEFAULT_TREND_DAYS
    end
  end
end
