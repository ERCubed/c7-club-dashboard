require "rails_helper"

RSpec.describe ClubMember, type: :model do
  it_behaves_like "a tenant scoped model" do
    let(:create_record) do
      ->(tenant) { ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-#{tenant.id}") }
    end
  end

  it "requires a commerce7_customer_id" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    member = ClubMember.new(tenant: tenant)

    expect(member).not_to be_valid
    expect(member.errors[:commerce7_customer_id]).to be_present
  end

  it "requires commerce7_customer_id to be unique within a tenant" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1")
    dupe = ClubMember.new(tenant: tenant, commerce7_customer_id: "cust-1")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:commerce7_customer_id]).to be_present
  end

  it "allows the same commerce7_customer_id across different tenants" do
    tenant_a = Tenant.create!(commerce7_tenant_id: "tenant-a")
    tenant_b = Tenant.create!(commerce7_tenant_id: "tenant-b")
    ClubMember.create!(tenant: tenant_a, commerce7_customer_id: "cust-1")
    other = ClubMember.new(tenant: tenant_b, commerce7_customer_id: "cust-1")

    expect(other).to be_valid
  end

  describe ".active" do
    it "only includes memberships with an Active status" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      active = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active")
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-2", status: "Cancelled")

      expect(ClubMember.active).to contain_exactly(active)
    end
  end

  describe ".top_spenders" do
    it "orders active members by lifetime value, excluding cancelled members" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      low = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-low", status: "Active")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-low", lifetime_value_cents: 100)
      high = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-high", status: "Active")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-high", lifetime_value_cents: 999)
      cancelled = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-cancelled", status: "Cancelled")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-cancelled", lifetime_value_cents: 5_000)

      expect(ClubMember.top_spenders).to eq([ high, low ])
      expect(ClubMember.top_spenders).not_to include(cancelled)
    end

    it "respects a custom limit" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      3.times do |i|
        ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-#{i}", status: "Active")
        OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-#{i}", lifetime_value_cents: i)
      end

      expect(ClubMember.top_spenders(1).size).to eq(1)
    end
  end

  describe ".at_risk" do
    it "includes active members with no recent order or no order at all, excluding cancelled members" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      stale = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-stale", status: "Active")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-stale", last_order_at: 1.year.ago)
      never_ordered = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-never", status: "Active")
      recent = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-recent", status: "Active")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-recent", last_order_at: 1.week.ago)
      cancelled = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-cancelled", status: "Cancelled")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-cancelled", last_order_at: 1.year.ago)

      expect(ClubMember.at_risk).to contain_exactly(stale, never_ordered)
      expect(ClubMember.at_risk).not_to include(recent, cancelled)
    end

    it "respects a custom months threshold" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      member = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-1", last_order_at: 2.months.ago)

      expect(ClubMember.at_risk(1)).to contain_exactly(member)
      expect(ClubMember.at_risk(3)).to be_empty
    end
  end

  describe ".tier_breakdown" do
    it "groups active members by tier, excluding cancelled members" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active", club_tier: "Red Club")
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-2", status: "Active", club_tier: "Red Club")
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-3", status: "Cancelled", club_tier: "Red Club")

      expect(ClubMember.tier_breakdown).to eq({ "Red Club" => 2 })
    end
  end

  describe ".tier_colors" do
    it "assigns colors by tier name in a fixed, alphabetical order" do
      colors = ClubMember.tier_colors([ "White Club", "Apple Club" ])

      expect(colors["Apple Club"]).to eq(ClubMember::TIER_COLORS[0])
      expect(colors["White Club"]).to eq(ClubMember::TIER_COLORS[1])
    end

    it "defaults to the current tier breakdown's tiers" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active", club_tier: "Red Club")

      expect(ClubMember.tier_colors.keys).to eq([ "Red Club" ])
    end

    it "prefers a tenant's tier_color_overrides over the fallback palette" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123", tier_color_overrides: { "Apple Club" => "#123abc" })
      Current.tenant = tenant

      colors = ClubMember.tier_colors([ "White Club", "Apple Club" ])

      expect(colors["Apple Club"]).to eq("#123abc")
      expect(colors["White Club"]).to eq(ClubMember::TIER_COLORS[1])
    end

    it "ignores a stale override for a tier not in the passed list" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123", tier_color_overrides: { "Retired Club" => "#123abc" })
      Current.tenant = tenant

      colors = ClubMember.tier_colors([ "White Club" ])

      expect(colors).not_to have_key("Retired Club")
    end
  end

  describe "#at_risk?" do
    it "is false for a cancelled member regardless of order history" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      member = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Cancelled")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-1", last_order_at: 2.years.ago)

      expect(member.at_risk?).to be false
    end

    it "is true for an active member with no order_summary at all" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      member = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active")

      expect(member.at_risk?).to be true
    end

    it "respects a custom months threshold" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      Current.tenant = tenant
      member = ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active")
      OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-1", last_order_at: 2.months.ago)

      expect(member.at_risk?(1)).to be true
      expect(member.at_risk?(3)).to be false
    end
  end
end
