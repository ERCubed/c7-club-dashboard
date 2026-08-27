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

  describe ".activate!" do
    it "creates a new tenant with the activation payload" do
      tenant = Tenant.activate!(commerce7_tenant_id: "winery-1", payload: { "email" => "jane@example.com" })

      expect(tenant.activated_at).to be_present
      expect(tenant.deactivated_at).to be_nil
      expect(tenant.raw_activation_payload).to eq({ "email" => "jane@example.com" })
    end

    it "reactivates and clears deactivated_at on an existing tenant" do
      existing = Tenant.create!(commerce7_tenant_id: "winery-1", deactivated_at: 1.day.ago)

      tenant = Tenant.activate!(commerce7_tenant_id: "winery-1", payload: {})

      expect(tenant).to eq(existing)
      expect(Tenant.count).to eq(1)
      expect(tenant.deactivated_at).to be_nil
    end
  end

  describe "#deactivate!" do
    it "sets deactivated_at without deleting the tenant" do
      tenant = Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago)

      tenant.deactivate!

      expect(tenant.deactivated_at).to be_present
      expect(Tenant.count).to eq(1)
    end
  end
end
