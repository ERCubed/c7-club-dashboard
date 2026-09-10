require "rails_helper"

RSpec.describe "Commerce7 webhooks", type: :request do
  include ActiveJob::TestHelper

  let!(:tenant) { Tenant.create!(commerce7_tenant_id: "winery-1") }
  let!(:username) { Rails.application.credentials.dig(:commerce7, :webhook_username) }
  let!(:password) { Rails.application.credentials.dig(:commerce7, :webhook_password) }
  let(:auth_headers) { { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) } }

  def post_webhook(object:, action:, payload: {}, tenant_id: "winery-1")
    post commerce7_webhooks_path,
      params: { tenantId: tenant_id, object: object, action: action, payload: payload },
      headers: auth_headers,
      as: :json
  end

  def create_member(customer_id:)
    Current.tenant = tenant
    ClubMember.create!(tenant: tenant, commerce7_customer_id: customer_id, name: "Test Member")
    OrderSummary.create!(tenant: tenant, commerce7_customer_id: customer_id)
    Current.tenant = nil
  end

  it "returns 401 when the credentials are wrong" do
    post commerce7_webhooks_path,
      params: { tenantId: "winery-1", object: "Customer", action: "Delete", payload: { customerId: "cust-1" } },
      headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("wrong", "wrong") },
      as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 400 when a required top-level field is missing" do
    post commerce7_webhooks_path, params: { tenantId: "winery-1", object: "Customer" }, headers: auth_headers, as: :json

    expect(response).to have_http_status(:bad_request)
  end

  it "acks and no-ops for an unknown tenant, rather than erroring" do
    expect {
      post_webhook(object: "Customer", action: "Delete", payload: { customerId: "cust-1" }, tenant_id: "unknown-winery")
    }.not_to have_enqueued_job(Commerce7::SyncJob)

    expect(response).to have_http_status(:ok)
  end

  it "acks and no-ops for an object/action combo it doesn't recognize" do
    post_webhook(object: "Order", action: "Create", payload: { id: "order-1" })

    expect(response).to have_http_status(:ok)
  end

  it "acks and no-ops for a Club Membership action it doesn't recognize" do
    post_webhook(object: "Club Membership", action: "Bulk Update", payload: {})

    expect(response).to have_http_status(:ok)
  end

  it "returns 400 for a malformed JSON body" do
    post commerce7_webhooks_path, params: "not json", headers: auth_headers.merge("CONTENT_TYPE" => "application/json")

    expect(response).to have_http_status(:bad_request)
  end

  describe "Club Membership Create/Update" do
    it "enqueues a SyncJob scoped to the tenant, rather than upserting directly from the payload" do
      expect {
        post_webhook(object: "Club Membership", action: "Create", payload: { customerId: "cust-1" })
      }.to have_enqueued_job(Commerce7::SyncJob).with(tenant)

      expect(response).to have_http_status(:ok)
    end

    it "does the same for Update" do
      expect {
        post_webhook(object: "Club Membership", action: "Update", payload: { customerId: "cust-1" })
      }.to have_enqueued_job(Commerce7::SyncJob).with(tenant)
    end

    it "is idempotent — a repeated delivery just enqueues another equivalent sync" do
      stub_request(:get, "https://api.commerce7.com/v1/club-membership")
        .with(query: hash_including("page" => "1"), headers: { "tenant" => "winery-1" })
        .to_return(status: 200, body: { "clubMemberships" => [] }.to_json, headers: { "Content-Type" => "application/json" })

      perform_enqueued_jobs do
        post_webhook(object: "Club Membership", action: "Update", payload: { customerId: "cust-1" })
        post_webhook(object: "Club Membership", action: "Update", payload: { customerId: "cust-1" })
      end

      expect(response).to have_http_status(:ok)
    end
  end

  describe "Club Membership Delete" do
    it "removes the ClubMember and OrderSummary for that customer" do
      create_member(customer_id: "cust-1")

      post_webhook(object: "Club Membership", action: "Delete", payload: { customerId: "cust-1" })

      expect(response).to have_http_status(:ok)
      Current.tenant = tenant
      expect(ClubMember.find_by(commerce7_customer_id: "cust-1")).to be_nil
      expect(OrderSummary.find_by(commerce7_customer_id: "cust-1")).to be_nil
    end

    it "is idempotent — deleting an already-gone member is a safe no-op" do
      post_webhook(object: "Club Membership", action: "Delete", payload: { customerId: "cust-never-existed" })

      expect(response).to have_http_status(:ok)
    end

    it "is a no-op when the payload has no customerId" do
      post_webhook(object: "Club Membership", action: "Delete", payload: {})

      expect(response).to have_http_status(:ok)
    end
  end

  describe "Customer Delete" do
    it "removes the ClubMember and OrderSummary for that customer" do
      create_member(customer_id: "cust-1")

      post_webhook(object: "Customer", action: "Delete", payload: { customerId: "cust-1" })

      expect(response).to have_http_status(:ok)
      Current.tenant = tenant
      expect(ClubMember.find_by(commerce7_customer_id: "cust-1")).to be_nil
      expect(OrderSummary.find_by(commerce7_customer_id: "cust-1")).to be_nil
    end

    it "does not delete anything for a Customer Create/Update event" do
      create_member(customer_id: "cust-1")

      post_webhook(object: "Customer", action: "Update", payload: { customerId: "cust-1" })

      expect(response).to have_http_status(:ok)
      Current.tenant = tenant
      expect(ClubMember.find_by(commerce7_customer_id: "cust-1")).to be_present
    end

    it "is idempotent across repeated deliveries" do
      create_member(customer_id: "cust-1")

      post_webhook(object: "Customer", action: "Delete", payload: { customerId: "cust-1" })
      post_webhook(object: "Customer", action: "Delete", payload: { customerId: "cust-1" })

      expect(response).to have_http_status(:ok)
      Current.tenant = tenant
      expect(ClubMember.find_by(commerce7_customer_id: "cust-1")).to be_nil
    end
  end
end
