require "rails_helper"

RSpec.describe Commerce7::SyncJob do
  let(:json_headers) { { "Content-Type" => "application/json" } }

  def membership(customer_id:, club_title:, current_club_title: club_title, status: "Active", signup_date: "2020-01-01T00:00:00.000Z", email: "member@example.com")
    {
      "customerId" => customer_id,
      "status" => status,
      "signupDate" => signup_date,
      "customer" => {
        "firstName" => "Jane",
        "lastName" => "Doe",
        "emails" => [ { "email" => email } ],
        "orderInformation" => {
          "currentClubTitle" => current_club_title,
          "lastOrderDate" => "2026-01-15T00:00:00.000Z",
          "orderCount" => 5,
          "lifetimeValue" => 24110
        }
      },
      "club" => { "title" => club_title }
    }
  end

  def stub_memberships(tenant, records)
    stub_request(:get, "https://api.commerce7.com/v1/club-membership")
      .with(query: hash_including("page" => "1"), headers: { "tenant" => tenant.commerce7_tenant_id })
      .to_return(status: 200, body: { "clubMemberships" => records }.to_json, headers: json_headers)
  end

  after { Current.tenant = nil }

  it "upserts a ClubMember and OrderSummary from a club membership record" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1")
    stub_memberships(tenant, [ membership(customer_id: "cust-1", club_title: "Red Club") ])

    described_class.perform_now

    Current.tenant = tenant
    member = ClubMember.find_by!(commerce7_customer_id: "cust-1")
    expect(member).to have_attributes(
      name: "Jane Doe",
      email: "member@example.com",
      club_tier: "Red Club",
      status: "Active",
      joined_at: Time.zone.parse("2020-01-01T00:00:00.000Z")
    )

    summary = OrderSummary.find_by!(commerce7_customer_id: "cust-1")
    expect(summary).to have_attributes(
      lifetime_value_cents: 24110,
      order_count: 5,
      last_order_at: Time.zone.parse("2026-01-15T00:00:00.000Z")
    )
  end

  it "updates existing records rather than duplicating them" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1")
    stub_memberships(tenant, [ membership(customer_id: "cust-1", club_title: "Red Club") ])
    described_class.perform_now

    stub_memberships(tenant, [ membership(customer_id: "cust-1", club_title: "Red Club", status: "Cancelled") ])
    described_class.perform_now

    Current.tenant = tenant
    expect(ClubMember.count).to eq(1)
    expect(ClubMember.sole.status).to eq("Cancelled")
  end

  it "keeps the membership matching the customer's current club when there are several" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1")
    stub_memberships(tenant, [
      membership(customer_id: "cust-1", club_title: "Red Club", current_club_title: "White Club"),
      membership(customer_id: "cust-1", club_title: "White Club", current_club_title: "White Club")
    ])

    described_class.perform_now

    Current.tenant = tenant
    expect(ClubMember.sole.club_tier).to eq("White Club")
  end

  it "does not let a later non-matching membership replace an already-matched one" do
    tenant = Tenant.create!(commerce7_tenant_id: "winery-1")
    stub_memberships(tenant, [
      membership(customer_id: "cust-1", club_title: "White Club", current_club_title: "White Club"),
      membership(customer_id: "cust-1", club_title: "Red Club", current_club_title: "White Club")
    ])

    described_class.perform_now

    Current.tenant = tenant
    expect(ClubMember.sole.club_tier).to eq("White Club")
  end

  it "syncs every active tenant and skips deactivated ones" do
    active = Tenant.create!(commerce7_tenant_id: "winery-active")
    deactivated = Tenant.create!(commerce7_tenant_id: "winery-deactivated", deactivated_at: Time.current)
    active_stub = stub_memberships(active, [ membership(customer_id: "cust-1", club_title: "Red Club") ])

    described_class.perform_now

    expect(active_stub).to have_been_requested
    Current.tenant = deactivated
    expect(ClubMember.count).to eq(0)
  end

  it "logs and continues past a tenant whose sync fails" do
    failing = Tenant.create!(commerce7_tenant_id: "winery-failing")
    healthy = Tenant.create!(commerce7_tenant_id: "winery-healthy")
    stub_request(:get, "https://api.commerce7.com/v1/club-membership")
      .with(query: hash_including("page" => "1"), headers: { "tenant" => "winery-failing" })
      .to_return(status: 500, body: "boom")
    stub_memberships(healthy, [ membership(customer_id: "cust-2", club_title: "Red Club") ])

    expect(Rails.logger).to receive(:error).with(/winery-failing/)

    described_class.perform_now

    Current.tenant = healthy
    expect(ClubMember.find_by(commerce7_customer_id: "cust-2")).to be_present
  end
end
