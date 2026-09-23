module Commerce7
  # Recurring job (see config/recurring.yml) that captures a daily point-in-time
  # snapshot of each active tenant's membership metrics, so the dashboard can
  # chart trends over time — ClubMember/OrderSummary only ever hold current
  # state, with no history of their own.
  #
  # Runs after Commerce7::SyncJob's daily reconciliation so a given day's
  # snapshot reflects that day's synced data. Idempotent by construction
  # (find_or_initialize_by tenant+date) — a retry or a manual re-run for
  # today just overwrites today's snapshot rather than duplicating it.
  class SnapshotMetricsJob < ApplicationJob
    queue_as :default

    def perform
      Tenant.active.find_each { |tenant| snapshot(tenant) }
    end

    private

    def snapshot(tenant)
      Current.tenant = tenant
      TenantMetricSnapshot.find_or_initialize_by(tenant: tenant, snapshot_date: Date.current).update!(
        active_members_count: ClubMember.tier_breakdown.values.sum,
        revenue_cents: ClubMember.revenue_by_tier.values.sum,
        at_risk_count: ClubMember.at_risk.count
      )
    ensure
      Current.tenant = nil
    end
  end
end
