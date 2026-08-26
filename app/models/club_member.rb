class ClubMember < ApplicationRecord
  include TenantScoped

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

  # Joined on the Commerce7 customer id rather than a real foreign key — both
  # tables are populated independently from the same sync (Commerce7::SyncJob)
  # and neither owns the other.
  has_one :order_summary, foreign_key: :commerce7_customer_id, primary_key: :commerce7_customer_id, inverse_of: :club_member

  validates :commerce7_customer_id, presence: true, uniqueness: { scope: :tenant_id }

  scope :active, -> { where(status: "Active") }

  scope :top_spenders, ->(limit = 10) {
    active.joins(:order_summary).includes(:order_summary)
      .order(order_summaries: { lifetime_value_cents: :desc })
      .limit(limit)
  }

  # SQL-side equivalent of #at_risk? below, for filtering/counting many
  # members at once — the two must stay logically equivalent.
  scope :at_risk, ->(months = DEFAULT_AT_RISK_MONTHS) {
    active.left_joins(:order_summary)
      .where("order_summaries.last_order_at IS NULL OR order_summaries.last_order_at < ?", months.months.ago)
  }

  def self.tier_breakdown
    active.group(:club_tier).count
  end

  # Assigns colors by tier name, not by current size — a filter or a
  # membership shift must never repaint a tier that's already on screen.
  def self.tier_colors(tiers = tier_breakdown.keys)
    tiers.sort_by(&:to_s).each_with_index.to_h { |tier, index| [ tier, TIER_COLORS[index % TIER_COLORS.length] ] }
  end

  # Ruby-side equivalent of the .at_risk scope above, for a single
  # already-loaded member (e.g. with order_summary preloaded) where issuing
  # another query would be wasteful — the two must stay logically equivalent.
  def at_risk?(months = DEFAULT_AT_RISK_MONTHS)
    status == "Active" && (order_summary.nil? || order_summary.last_order_at.nil? || order_summary.last_order_at < months.months.ago)
  end
end
