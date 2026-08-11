require "rails_helper"

RSpec.describe "Commerce7 activations", type: :request do
  let!(:token) { Rails.application.credentials.dig(:commerce7, :webhook_token) }

  it "creates a new tenant from the activation payload" do
    post commerce7_activate_path(token: token), params: { tenantId: "winery-1", apiKey: "key-1", apiSecret: "secret-1" }

    expect(response).to have_http_status(:ok)

    tenant = Tenant.find_by(commerce7_tenant_id: "winery-1")
    expect(tenant).to be_present
    expect(tenant.activated_at).to be_present
    expect(tenant.deactivated_at).to be_nil
    expect(tenant.api_key).to eq("key-1")
    expect(tenant.api_secret).to eq("secret-1")
    expect(tenant.raw_activation_payload["tenantId"]).to eq("winery-1")
    expect(tenant.raw_activation_payload).not_to have_key("apiKey")
    expect(tenant.raw_activation_payload).not_to have_key("apiSecret")
  end

  it "reactivates an existing tenant and clears deactivated_at" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1", api_key: "old-key", api_secret: "old-secret", deactivated_at: 1.day.ago)

    post commerce7_activate_path(token: token), params: { tenantId: "winery-1", apiKey: "new-key", apiSecret: "new-secret" }

    expect(response).to have_http_status(:ok)
    expect(Tenant.count).to eq(1)
    tenant.reload
    expect(tenant.deactivated_at).to be_nil
    expect(tenant.api_key).to eq("new-key")
    expect(tenant.api_secret).to eq("new-secret")
  end

  it "retains previously stored credentials when the payload omits them" do
    Tenant.create!(commerce7_tenant_id: "winery-1", api_key: "old-key", api_secret: "old-secret", deactivated_at: 1.day.ago)

    post commerce7_activate_path(token: token), params: { tenantId: "winery-1" }

    expect(response).to have_http_status(:ok)
    tenant = Tenant.find_by(commerce7_tenant_id: "winery-1")
    expect(tenant.api_key).to eq("old-key")
    expect(tenant.api_secret).to eq("old-secret")
  end

  it "returns 400 when tenantId is missing" do
    post commerce7_activate_path(token: token), params: {}

    expect(response).to have_http_status(:bad_request)
  end

  it "returns 401 when the token is wrong" do
    post commerce7_activate_path(token: "wrong-token"), params: { tenantId: "winery-1" }

    expect(response).to have_http_status(:unauthorized)
    expect(Tenant.find_by(commerce7_tenant_id: "winery-1")).to be_nil
  end

  it "returns 401 when no webhook token is configured" do
    allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :webhook_token).and_return(nil)

    post commerce7_activate_path(token: token), params: { tenantId: "winery-1" }

    expect(response).to have_http_status(:unauthorized)
  end
end
