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
end
