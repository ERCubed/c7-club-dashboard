require "rails_helper"

RSpec.describe "Commerce7 deactivations", type: :request do
  let!(:token) { Rails.application.credentials.dig(:commerce7, :webhook_token) }

  it "deactivates an existing tenant" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago)

    post commerce7_deactivate_path(token: token), params: { tenantId: "winery-1" }

    expect(response).to have_http_status(:ok)
    expect(tenant.reload.deactivated_at).to be_present
  end

  it "is a no-op for an unrecognized tenantId" do
    post commerce7_deactivate_path(token: token), params: { tenantId: "unknown-winery" }

    expect(response).to have_http_status(:ok)
    expect(Tenant.count).to eq(0)
  end

  it "returns 400 when tenantId is missing" do
    post commerce7_deactivate_path(token: token), params: {}

    expect(response).to have_http_status(:bad_request)
  end

  it "returns 401 when the token is wrong" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago)

    post commerce7_deactivate_path(token: "wrong-token"), params: { tenantId: "winery-1" }

    expect(response).to have_http_status(:unauthorized)
    expect(tenant.reload.deactivated_at).to be_nil
  end
end
