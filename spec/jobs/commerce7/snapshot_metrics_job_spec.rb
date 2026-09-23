require "rails_helper"

RSpec.describe Commerce7::SnapshotMetricsJob do
  after { Current.tenant = nil }

  def create_member(tenant:, customer_id:, club_tier: "Red Club", status: "Active", lifetime_value_cents: 0, last_order_at: nil)
    Current.tenant = tenant
    ClubMember.create!(tenant: tenant, commerce7_customer_id: customer_id, club_tier: club_tier, status: status)
    OrderSummary.create!(tenant: tenant, commerce7_customer_id: customer_id, lifetime_value_cents: lifetime_value_cents, last_order_at: last_order_at)
    Current.tenant = nil
  end

  it "creates today's snapshot with active member count, revenue, and at-risk count" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago)
    create_member(tenant: tenant, customer_id: "cust-1", lifetime_value_cents: 10_000, last_order_at: 1.week.ago)
    create_member(tenant: tenant, customer_id: "cust-2", lifetime_value_cents: 5_000, last_order_at: 1.year.ago)
    create_member(tenant: tenant, customer_id: "cust-3", status: "Cancelled", lifetime_value_cents: 99_999)

    described_class.perform_now

    Current.tenant = tenant
    snapshot = TenantMetricSnapshot.find_by(snapshot_date: Date.current)
    expect(snapshot.active_members_count).to eq(2)
    expect(snapshot.revenue_cents).to eq(15_000)
    expect(snapshot.at_risk_count).to eq(1)
  end

  it "only snapshots active tenants" do
    deactivated = Tenant.create!(commerce7_tenant_id: "winery-inactive", deactivated_at: 1.day.ago)

    described_class.perform_now

    Current.tenant = deactivated
    expect(TenantMetricSnapshot.find_by(snapshot_date: Date.current)).to be_nil
  end

  it "is idempotent — re-running the same day overwrites rather than duplicates today's snapshot" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago)
    create_member(tenant: tenant, customer_id: "cust-1", lifetime_value_cents: 1_000)

    described_class.perform_now
    create_member(tenant: tenant, customer_id: "cust-2", lifetime_value_cents: 1_000)
    described_class.perform_now

    Current.tenant = tenant
    expect(TenantMetricSnapshot.where(snapshot_date: Date.current).count).to eq(1)
    expect(TenantMetricSnapshot.find_by(snapshot_date: Date.current).active_members_count).to eq(2)
  end
end
