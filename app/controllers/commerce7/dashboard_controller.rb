module Commerce7
  # Reports > Club Report App Extension page. Reads the data Commerce7::SyncJob
  # already synced into ClubMember/OrderSummary — this controller never calls
  # Commerce7's API itself.
  class DashboardController < ExtensionController
    DEFAULT_AT_RISK_MONTHS = 6

    def show
      @at_risk_months = at_risk_months
      @tier_breakdown = ClubMember.active.group(:club_tier).count
      @top_spenders = ClubMember.active.joins(:order_summary).includes(:order_summary)
        .order(order_summaries: { lifetime_value_cents: :desc })
        .limit(10)

      at_risk_scope = ClubMember.active.left_joins(:order_summary)
        .where("order_summaries.last_order_at IS NULL OR order_summaries.last_order_at < ?", @at_risk_months.months.ago)
      @at_risk_count = at_risk_scope.count
      @at_risk_members = at_risk_scope.includes(:order_summary)
        .order(Arel.sql("order_summaries.last_order_at ASC NULLS FIRST")).limit(50)
    end

    private

    def at_risk_months
      months = params[:at_risk_months].to_i
      months.positive? ? months : DEFAULT_AT_RISK_MONTHS
    end
  end
end
