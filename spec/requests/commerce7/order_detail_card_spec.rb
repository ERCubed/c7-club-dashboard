require "rails_helper"

RSpec.describe "Commerce7 order detail card", type: :request do
  let!(:tenant) { Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago) }
  let(:user_payload) { { "id" => "staff-1", "firstName" => "Jason", "lastName" => "Andres", "email" => "jason@example.com", "role" => "Admin Owner" } }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  before do
    stub_request(:get, "https://api.commerce7.com/v1/account/user")
      .to_return(status: 200, body: user_payload.to_json, headers: json_headers)
  end

  def create_member(customer_id:, status: "Active", club_tier: "Red Club", lifetime_value_cents: 0, order_count: 0, last_order_at: nil)
    Current.tenant = tenant
    ClubMember.create!(tenant: tenant, commerce7_customer_id: customer_id, name: "Test Member", club_tier: club_tier, status: status, joined_at: 1.year.ago)
    OrderSummary.create!(tenant: tenant, commerce7_customer_id: customer_id, lifetime_value_cents: lifetime_value_cents, order_count: order_count, last_order_at: last_order_at)
    Current.tenant = nil
  end

  it "shows the club summary for a known customer" do
    create_member(customer_id: "cust-1", lifetime_value_cents: 24_110, order_count: 5, last_order_at: 1.week.ago)

    get commerce7_order_detail_card_path, params: { tenantId: "winery-1", account: "jwt-token", customerId: "cust-1" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Red Club")
    expect(response.body).to include("Active")
    expect(response.body).to include("$241.10")
    expect(response.body).not_to include("At risk")
  end

  it "flags an active member who hasn't ordered recently" do
    create_member(customer_id: "cust-1", last_order_at: 7.months.ago)

    get commerce7_order_detail_card_path, params: { tenantId: "winery-1", account: "jwt-token", customerId: "cust-1" }

    expect(response.body).to include("At risk")
  end

  it "does not flag a cancelled member as at risk" do
    create_member(customer_id: "cust-1", status: "Cancelled", last_order_at: 2.years.ago)

    get commerce7_order_detail_card_path, params: { tenantId: "winery-1", account: "jwt-token", customerId: "cust-1" }

    expect(response.body).to include("Cancelled")
    expect(response.body).not_to include("At risk")
  end

  it "shows an empty state when the customer is not a club member" do
    get commerce7_order_detail_card_path, params: { tenantId: "winery-1", account: "jwt-token", customerId: "unknown-customer" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Not a Commerce7 club member.")
  end

  it "shows an empty state when no customerId is present" do
    get commerce7_order_detail_card_path, params: { tenantId: "winery-1", account: "jwt-token" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Not a Commerce7 club member.")
  end
end
