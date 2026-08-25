module Commerce7
  # Reports > Club Report App Extension page. Reads the data Commerce7::SyncJob
  # already synced into ClubMember/OrderSummary — this controller never calls
  # Commerce7's API itself.
  class DashboardController < ExtensionController
    DEFAULT_AT_RISK_MONTHS = 6

    # Reference categorical palette (see the dataviz skill's palette.md) —
    # fixed hue order, never cycled per tier's rank so a tier keeps its color
    # across renders even as membership shifts which tier is largest.
    #
    # TODO: this is just "next color in the list" per tier, which can land
    # oddly for tiers named after colors (e.g. Red Club landing on blue) —
    # revisit with real per-tenant tier names, e.g. a name -> hue override
    # for color-named tiers, falling back to this palette otherwise.
    TIER_COLORS = %w[#2a78d6 #eb6834 #1baf7a #eda100 #e87ba4 #008300 #4a3aa7 #e34948].freeze

    def show
      @at_risk_months = at_risk_months
      @tier_breakdown = ClubMember.active.group(:club_tier).count
      @tier_colors = assign_tier_colors(@tier_breakdown.keys)
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

    # Assigns colors by tier name, not by current size — a filter or a
    # membership shift must never repaint a tier that's already on screen.
    def assign_tier_colors(tiers)
      tiers.sort_by(&:to_s).each_with_index.to_h { |tier, index| [ tier, TIER_COLORS[index % TIER_COLORS.length] ] }
    end
  end
end
