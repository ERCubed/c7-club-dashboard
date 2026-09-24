require "rails_helper"

# Commerce7::WebhooksController itself (auth, JSON parsing, tenant lookup,
# dispatch, audit) is gem-owned and tested there (see commerce7-rails).
# This covers what's actually this app's code: the handlers registered
# against Commerce7::Webhooks in config/initializers/commerce7.rb.
RSpec.describe "Commerce7 webhooks", type: :request do
  include ActiveJob::TestHelper

  let!(:tenant) { Tenant.create!(commerce7_tenant_id: "winery-1") }
  let!(:username) { "c7-user" }
  let!(:password) { "c7-pass" }
  let(:auth_headers) { { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(username, password) } }

  def post_webhook(object:, action:, payload: {}, user: "staff@example.com")
    post commerce7_webhooks_path,
      params: { tenantId: "winery-1", object: object, action: action, payload: payload, user: user },
      headers: auth_headers,
      as: :json
  end

  def create_member(customer_id:)
    Current.tenant = tenant
    ClubMember.create!(tenant: tenant, commerce7_customer_id: customer_id, name: "Test Member")
    OrderSummary.create!(tenant: tenant, commerce7_customer_id: customer_id)
    Current.tenant = nil
  end

  describe "Club Membership Create/Update" do
    it "enqueues a SyncJob scoped to the tenant, rather than upserting directly from the payload" do
      expect {
        post_webhook(object: "Club Membership", action: "Create", payload: { customerId: "cust-1" }, user: "jason@example.com")
      }.to have_enqueued_job(Commerce7::SyncJob).with(tenant)

      expect(response).to have_http_status(:ok)
      expect(AuditEvent.last).to have_attributes(
        event_type: "webhook_club_membership_create",
        success: true,
        actor: "jason@example.com",
        commerce7_tenant_id: "winery-1"
      )
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
      expect(AuditEvent.last).to have_attributes(event_type: "webhook_club_membership_delete", success: true, commerce7_tenant_id: "winery-1")
    end

    it "is idempotent — deleting an already-gone member is a safe no-op" do
      post_webhook(object: "Club Membership", action: "Delete", payload: { customerId: "cust-never-existed" })

      expect(response).to have_http_status(:ok)
    end

    it "refreshes today's trend snapshot" do
      Current.tenant = tenant
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-1", status: "Active")
      ClubMember.create!(tenant: tenant, commerce7_customer_id: "cust-2", status: "Active")
      Current.tenant = nil

      post_webhook(object: "Club Membership", action: "Delete", payload: { customerId: "cust-1" })

      Current.tenant = tenant
      expect(TenantMetricSnapshot.find_by(snapshot_date: Date.current).active_members_count).to eq(1)
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
      expect(AuditEvent.last).to have_attributes(event_type: "webhook_customer_delete", success: true, commerce7_tenant_id: "winery-1")
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
