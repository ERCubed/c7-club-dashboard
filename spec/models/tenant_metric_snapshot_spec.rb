require "rails_helper"

RSpec.describe TenantMetricSnapshot, type: :model do
  it_behaves_like "a tenant scoped model" do
    let(:create_record) do
      ->(tenant) { TenantMetricSnapshot.create!(tenant: tenant, snapshot_date: Date.current) }
    end
  end

  it "requires a snapshot_date" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    snapshot = TenantMetricSnapshot.new(tenant: tenant)

    expect(snapshot).not_to be_valid
    expect(snapshot.errors[:snapshot_date]).to be_present
  end

  it "requires snapshot_date to be unique within a tenant" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    Current.tenant = tenant
    TenantMetricSnapshot.create!(tenant: tenant, snapshot_date: Date.current)
    dupe = TenantMetricSnapshot.new(tenant: tenant, snapshot_date: Date.current)

    expect(dupe).not_to be_valid
    expect(dupe.errors[:snapshot_date]).to be_present
  end

  it "allows the same snapshot_date across different tenants" do
    tenant_a = Tenant.create!(commerce7_tenant_id: "tenant-a")
    tenant_b = Tenant.create!(commerce7_tenant_id: "tenant-b")
    Current.tenant = tenant_a
    TenantMetricSnapshot.create!(tenant: tenant_a, snapshot_date: Date.current)
    Current.tenant = tenant_b
    other = TenantMetricSnapshot.new(tenant: tenant_b, snapshot_date: Date.current)

    expect(other).to be_valid
  end

  describe ".capture!" do
    it "creates today's snapshot from the tenant's current ClubMember/OrderSummary state" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-1", lifetime_value_cents: 5_000, last_order_at: 1.year.ago)

      TenantMetricSnapshot.capture!(tenant)

      snapshot = TenantMetricSnapshot.find_by(snapshot_date: Date.current)
      expect(snapshot.active_members_count).to eq(1)
      expect(snapshot.revenue_cents).to eq(5_000)
      expect(snapshot.at_risk_count).to eq(1)
    end

    it "refreshes rather than duplicates today's snapshot on a repeat call" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active")

      TenantMetricSnapshot.capture!(tenant)
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-2", status: "Active")
      TenantMetricSnapshot.capture!(tenant)

      expect(TenantMetricSnapshot.where(snapshot_date: Date.current).count).to eq(1)
      expect(TenantMetricSnapshot.find_by(snapshot_date: Date.current).active_members_count).to eq(2)
    end
  end

  describe ".recent" do
    it "only includes snapshots within the given day window, oldest first" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      old = TenantMetricSnapshot.create!(tenant: tenant, snapshot_date: 100.days.ago.to_date)
      recent = TenantMetricSnapshot.create!(tenant: tenant, snapshot_date: 10.days.ago.to_date)
      today = TenantMetricSnapshot.create!(tenant: tenant, snapshot_date: Date.current)

      expect(TenantMetricSnapshot.recent(90)).to eq([ recent, today ])
      expect(TenantMetricSnapshot.recent(90)).not_to include(old)
    end

    it "defaults to 90 days" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      TenantMetricSnapshot.create!(tenant: tenant, snapshot_date: 91.days.ago.to_date)
      within_window = TenantMetricSnapshot.create!(tenant: tenant, snapshot_date: 89.days.ago.to_date)

      expect(TenantMetricSnapshot.recent).to eq([ within_window ])
    end
  end
end
