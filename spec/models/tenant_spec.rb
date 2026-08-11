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

  it "encrypts api_key and api_secret at rest" do
    tenant = Tenant.create!(commerce7_tenant_id: "abc123", api_key: "key-123", api_secret: "secret-456")

    raw = ActiveRecord::Base.connection.select_one(
      "SELECT api_key, api_secret FROM tenants WHERE id = #{tenant.id}"
    )

    expect(raw["api_key"]).not_to eq("key-123")
    expect(raw["api_secret"]).not_to eq("secret-456")
    expect(tenant.reload.api_key).to eq("key-123")
    expect(tenant.reload.api_secret).to eq("secret-456")
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
