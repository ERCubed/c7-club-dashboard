require "rails_helper"

RSpec.describe "Commerce7 dashboard", type: :request do
  let!(:tenant) { Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago) }
  let(:user_payload) { { "id" => "staff-1", "firstName" => "Jason", "lastName" => "Andres", "email" => "jason@example.com", "role" => "Admin Owner" } }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:auth_params) { { tenantId: "winery-1", account: "jwt-token" } }

  before do
    stub_request(:get, "https://api.commerce7.com/v1/account/user")
      .to_return(status: 200, body: user_payload.to_json, headers: json_headers)
  end

  def create_member(customer_id:, name:, club_tier:, status: "Active", lifetime_value_cents: 0, order_count: 0, last_order_at: nil)
    Current.tenant = tenant
    member = ClubMember.create!(tenant: tenant, commerce7_customer_id: customer_id, name: name, email: "#{customer_id}@example.com", club_tier: club_tier, status: status, joined_at: 1.year.ago)
    OrderSummary.create!(tenant: tenant, commerce7_customer_id: customer_id, lifetime_value_cents: lifetime_value_cents, order_count: order_count, last_order_at: last_order_at)
    Current.tenant = nil
    member
  end

  it "renders membership counts, top spenders, and at-risk members" do
    create_member(customer_id: "cust-1", name: "Big Spender", club_tier: "Red Club", lifetime_value_cents: 50_000, order_count: 10, last_order_at: 1.week.ago)
    create_member(customer_id: "cust-2", name: "Lapsed Member", club_tier: "White Club", lifetime_value_cents: 1_000, order_count: 1, last_order_at: 1.year.ago)
    create_member(customer_id: "cust-3", name: "Cancelled Member", club_tier: "Red Club", status: "Cancelled", lifetime_value_cents: 99_999, order_count: 5)

    get commerce7_dashboard_path, params: auth_params

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Welcome back, Jason")
    expect(response.body).to include("Big Spender")
    expect(response.body).to include("$500.00")
    expect(response.body).to include("Lapsed Member")
    expect(response.body).not_to include("Cancelled Member")
  end

  it "respects a custom at_risk_months threshold" do
    create_member(customer_id: "cust-1", name: "Recent Member", club_tier: "Red Club", last_order_at: 2.months.ago)

    get commerce7_dashboard_path, params: auth_params.merge(at_risk_months: 1)

    expect(response.body).to include("Recent Member")
  end

  it "treats a non-positive at_risk_months as the default" do
    create_member(customer_id: "cust-1", name: "Old Member", club_tier: "Red Club", last_order_at: 7.months.ago)

    get commerce7_dashboard_path, params: auth_params.merge(at_risk_months: 0)

    expect(response.body).to include("Old Member")
    expect(response.body).to include("At risk (6+ months with no activity)")
  end

  it "shows empty states when there is no data" do
    get commerce7_dashboard_path, params: auth_params

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No active members yet.")
    expect(response.body).to include("No order data yet.")
    expect(response.body).to include("No members at risk right now.")
  end

  it "shows each tier's share of active membership" do
    3.times { |i| create_member(customer_id: "red-#{i}", name: "Red #{i}", club_tier: "Red Club") }
    create_member(customer_id: "cust-white", name: "White One", club_tier: "White Club")

    get commerce7_dashboard_path, params: auth_params

    expect(response.body).to include("Red Club")
    expect(response.body).to include("75.0%")
    expect(response.body).to include("White Club")
    expect(response.body).to include("25.0%")
  end

  it "assigns tier colors by name so they stay stable as relative size shifts" do
    create_member(customer_id: "cust-apple-1", name: "A1", club_tier: "Apple Club")
    create_member(customer_id: "cust-apple-2", name: "A2", club_tier: "Apple Club")
    5.times { |i| create_member(customer_id: "white-#{i}", name: "White #{i}", club_tier: "White Club") }

    get commerce7_dashboard_path, params: auth_params

    color_for = ->(label) { response.body[/aria-label="#{Regexp.escape(label)}:.*?background-color:\s*(#\w+)/m, 1] }
    expect(color_for.call("Apple Club")).to eq("#2a78d6")
    expect(color_for.call("White Club")).to eq("#eb6834")
  end

  it "drops the default X-Frame-Options so Commerce7 can embed the page" do
    get commerce7_dashboard_path, params: auth_params

    expect(response.headers["X-Frame-Options"]).to be_nil
  end

  it "returns 403 for an unknown tenant" do
    get commerce7_dashboard_path, params: { tenantId: "unknown", account: "jwt-token" }

    expect(response).to have_http_status(:forbidden)
  end
end
