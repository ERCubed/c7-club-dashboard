require "rails_helper"

RSpec.describe Commerce7::DashboardHelper, type: :helper do
  describe "#trend_chart_points" do
    it "scales values across the full plot width, first point at the left edge and last at the right" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      snapshots = [
        TenantMetricSnapshot.new(tenant: tenant, snapshot_date: 2.days.ago, active_members_count: 10),
        TenantMetricSnapshot.new(tenant: tenant, snapshot_date: 1.day.ago, active_members_count: 20),
        TenantMetricSnapshot.new(tenant: tenant, snapshot_date: Date.current, active_members_count: 30)
      ]

      points = helper.trend_chart_points(snapshots, :active_members_count)

      expect(points.first[:x]).to eq(Commerce7::DashboardHelper::TREND_CHART_PADDING.to_f)
      expect(points.last[:x]).to eq((Commerce7::DashboardHelper::TREND_CHART_WIDTH - Commerce7::DashboardHelper::TREND_CHART_PADDING).to_f)
      expect(points.map { |p| p[:value] }).to eq([ 10, 20, 30 ])
    end

    it "renders a flat, centered line without dividing by zero when every value is equal" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      snapshots = [
        TenantMetricSnapshot.new(tenant: tenant, snapshot_date: 1.day.ago, active_members_count: 5),
        TenantMetricSnapshot.new(tenant: tenant, snapshot_date: Date.current, active_members_count: 5)
      ]

      points = helper.trend_chart_points(snapshots, :active_members_count)

      expect(points.map { |p| p[:y] }).to all(eq(points.first[:y]))
    end

    it "returns an empty array for no snapshots, rather than dividing by nil" do
      expect(helper.trend_chart_points([], :active_members_count)).to eq([])
    end

    it "centers a single point rather than dividing by a zero-width step" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      snapshots = [ TenantMetricSnapshot.new(tenant: tenant, snapshot_date: Date.current, active_members_count: 5) ]

      points = helper.trend_chart_points(snapshots, :active_members_count)

      expect(points.first[:x]).to eq(Commerce7::DashboardHelper::TREND_CHART_WIDTH / 2.0)
    end
  end
end
