module Commerce7
  # Reports > Club Report App Extension page. Reads the data Commerce7::SyncJob
  # already synced into ClubMember/OrderSummary — this controller never calls
  # Commerce7's API itself.
  class DashboardController < ExtensionController
    def show
      @at_risk_months = at_risk_months
      @tier_breakdown = ClubMember.tier_breakdown
      @tier_colors = ClubMember.tier_colors(@tier_breakdown.keys)
      @top_spenders = ClubMember.top_spenders

      at_risk_scope = ClubMember.at_risk(@at_risk_months)
      @at_risk_count = at_risk_scope.count
      @at_risk_members = at_risk_scope.includes(:order_summary)
        .order(Arel.sql("order_summaries.last_order_at ASC NULLS FIRST")).limit(50)
    end

    private

    def at_risk_months
      months = params[:at_risk_months].to_i
      months.positive? ? months : ClubMember::DEFAULT_AT_RISK_MONTHS
    end
  end
end
