require "rails_helper"

RSpec.describe Tenant, type: :model do
  it "requires a commerce7_tenant_id" do
    tenant = Tenant.new
    expect(tenant).not_to be_valid
    expect(tenant.errors[:commerce7_tenant_id]).to be_present
  end

  it "requires commerce7_tenant_id to be unique" do
    Tenant.create!(commerce7_tenant_id: "abc123")
    dupe = Tenant.new(commerce7_tenant_id: "abc123")

    expect(dupe).not_to be_valid
    expect(dupe.errors[:commerce7_tenant_id]).to be_present
  end

  describe "#active?" do
    it "is active when deactivated_at is nil" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123")
      expect(tenant).to be_active
    end

    it "is not active once deactivated_at is set" do
      tenant = Tenant.create!(commerce7_tenant_id: "abc123", deactivated_at: Time.current)
      expect(tenant).not_to be_active
    end
  end

  describe ".active" do
    it "excludes deactivated tenants" do
      active = Tenant.create!(commerce7_tenant_id: "active-tenant")
      Tenant.create!(commerce7_tenant_id: "deactivated-tenant", deactivated_at: Time.current)

      expect(Tenant.active).to contain_exactly(active)
    end
  end
end
