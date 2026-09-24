require "rails_helper"

# Commerce7::ActivationsController itself (auth, tenant create/reactivate
# mechanics, audit) is gem-owned and tested there (see commerce7-rails).
# This covers what's actually this app's code: the on_activate hook
# registered in config/initializers/commerce7.rb.
RSpec.describe "Commerce7 activations", type: :request do
  let!(:username) { "c7-user" }
  let!(:password) { "c7-pass" }
  let(:auth_headers) { { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) } }

  it "creates a new tenant from the activation payload" do
    post commerce7_activate_path,
      params: { tenantId: "winery-1", firstName: "Jane", lastName: "Doe", email: "jane@example.com" },
      headers: auth_headers

    expect(response).to have_http_status(:ok)

    tenant = Tenant.find_by(commerce7_tenant_id: "winery-1")
    expect(tenant).to be_present
    expect(tenant.raw_activation_payload["email"]).to eq("jane@example.com")
  end

  it "enqueues a backfill sync scoped to the newly activated tenant" do
    expect {
      post commerce7_activate_path, params: { tenantId: "winery-1" }, headers: auth_headers
    }.to have_enqueued_job(Commerce7::SyncJob).with { |tenant| expect(tenant.commerce7_tenant_id).to eq("winery-1") }
  end

  it "reactivates an existing tenant, still scoped through the same on_activate hook" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1", deactivated_at: 1.day.ago)

    expect {
      post commerce7_activate_path, params: { tenantId: "winery-1" }, headers: auth_headers
    }.to have_enqueued_job(Commerce7::SyncJob).with(tenant)

    expect(Tenant.count).to eq(1)
    expect(tenant.reload.deactivated_at).to be_nil
  end
end
