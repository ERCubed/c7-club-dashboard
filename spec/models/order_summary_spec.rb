require "rails_helper"

RSpec.describe OrderSummary, type: :model do
  it_behaves_like "a tenant scoped model" do
    let(:create_record) do
      ->(tenant) { OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-#{tenant.id}") }
    end
  end

  it "requires a commerce7_customer_id" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    summary = OrderSummary.new(tenant: tenant)

    expect(summary).not_to be_valid
    expect(summary.errors[:commerce7_customer_id]).to be_present
  end

  it "requires commerce7_customer_id to be unique within a tenant" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    OrderSummary.create!(tenant: tenant, commerce7_customer_id: "cust-1")
    dupe = OrderSummary.new(tenant: tenant, commerce7_customer_id: "cust-1")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:commerce7_customer_id]).to be_present
  end

  it "rejects a negative order_count" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    summary = OrderSummary.new(tenant: tenant, commerce7_customer_id: "cust-1", order_count: -1)

    expect(summary).not_to be_valid
    expect(summary.errors[:order_count]).to be_present
  end

  it "rejects a negative lifetime_value" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123")
    summary = OrderSummary.new(tenant: tenant, commerce7_customer_id: "cust-1", lifetime_value: -1)

    expect(summary).not_to be_valid
    expect(summary.errors[:lifetime_value]).to be_present
  end
end
