class TenantMetricSnapshot < ApplicationRecord
  include TenantScoped

  validates :snapshot_date, presence: true, uniqueness: { scope: :tenant_id }

  scope :recent, ->(days = 90) { where(snapshot_date: days.days.ago.to_date..).order(:snapshot_date) }

  # Captures (or refreshes) today's snapshot for `tenant` from its currently-
  # synced ClubMember/OrderSummary data. Expects Current.tenant to already be
  # set to `tenant` by the caller — every call site already manages that
  # around its own tenant-scoped work (Commerce7::SyncJob#sync_tenant after
  # every sync, config/initializers/commerce7.rb's webhook delete handlers,
  # and Commerce7::SnapshotMetricsJob's daily safety-net run) — so today's
  # point on the trends chart stays live rather than only updating once a
  # day, without this model needing its own opinion on tenant scoping.
  def self.capture!(tenant)
    find_or_initialize_by(tenant: tenant, snapshot_date: Date.current).update!(
      active_members_count: ClubMember.tier_breakdown.values.sum,
      revenue_cents: ClubMember.revenue_by_tier.values.sum,
      at_risk_count: ClubMember.at_risk.count
    )
  end
end
