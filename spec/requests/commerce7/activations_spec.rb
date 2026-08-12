require "rails_helper"

RSpec.describe "Commerce7 activations", type: :request do
  let!(:username) { Rails.application.credentials.dig(:commerce7, :webhook_username) }
  let!(:password) { Rails.application.credentials.dig(:commerce7, :webhook_password) }
  let(:auth_headers) { { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) } }

  it "creates a new tenant from the activation payload" do
    post commerce7_activate_path,
      params: { tenantId: "winery-1", firstName: "Jane", lastName: "Doe", email: "jane@example.com" },
      headers: auth_headers

    expect(response).to have_http_status(:ok)

    tenant = Tenant.find_by(commerce7_tenant_id: "winery-1")
    expect(tenant).to be_present
    expect(tenant.activated_at).to be_present
    expect(tenant.deactivated_at).to be_nil
    expect(tenant.raw_activation_payload["tenantId"]).to eq("winery-1")
    expect(tenant.raw_activation_payload["email"]).to eq("jane@example.com")
  end

  it "reactivates an existing tenant and clears deactivated_at" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1", deactivated_at: 1.day.ago)

    post commerce7_activate_path, params: { tenantId: "winery-1" }, headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(Tenant.count).to eq(1)
    expect(tenant.reload.deactivated_at).to be_nil
  end

  it "returns 400 when tenantId is missing" do
    post commerce7_activate_path, params: {}, headers: auth_headers

    expect(response).to have_http_status(:bad_request)
  end

  it "returns 401 when the credentials are wrong" do
    bad_headers = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("wrong", "wrong") }

    post commerce7_activate_path, params: { tenantId: "winery-1" }, headers: bad_headers

    expect(response).to have_http_status(:unauthorized)
    expect(Tenant.find_by(commerce7_tenant_id: "winery-1")).to be_nil
  end

  it "returns 401 when the password is wrong but the username is right" do
    bad_headers = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, "wrong") }

    post commerce7_activate_path, params: { tenantId: "winery-1" }, headers: bad_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 when no webhook username is configured" do
    allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :webhook_username).and_return(nil)
    allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :webhook_password).and_return(password)

    post commerce7_activate_path, params: { tenantId: "winery-1" }, headers: auth_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 when no webhook password is configured" do
    allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :webhook_username).and_return(username)
    allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :webhook_password).and_return(nil)

    post commerce7_activate_path, params: { tenantId: "winery-1" }, headers: auth_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 when no Authorization header is sent at all" do
    post commerce7_activate_path, params: { tenantId: "winery-1" }

    expect(response).to have_http_status(:unauthorized)
  end
end
