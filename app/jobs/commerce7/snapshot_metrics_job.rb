module Commerce7
  # Recurring job (see config/recurring.yml) that captures today's snapshot
  # for every active tenant. TenantMetricSnapshot.capture! also runs after
  # every Commerce7::SyncJob sync (webhook-triggered or this job's own daily
  # reconciliation call) and after every webhook-driven delete (see
  # config/initializers/commerce7.rb), so this job is now a safety net for
  # any tenant with no sync/webhook activity that day — not the primary
  # source of a day's snapshot — mirroring why SyncJob's own daily run
  # stayed as a reconciliation pass once webhooks covered most updates.
  class SnapshotMetricsJob < ApplicationJob
    queue_as :default

    def perform
      Tenant.active.find_each { |tenant| snapshot(tenant) }
    end

    private

    def snapshot(tenant)
      Current.tenant = tenant
      TenantMetricSnapshot.capture!(tenant)
    ensure
      Current.tenant = nil
    end
  end
end
