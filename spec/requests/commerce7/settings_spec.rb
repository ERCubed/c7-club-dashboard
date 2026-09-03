require "rails_helper"

RSpec.describe "Commerce7 settings", type: :request do
  let!(:tenant) { Tenant.create!(commerce7_tenant_id: "winery-1", activated_at: 1.day.ago) }
  let(:user_payload) { { "id" => "staff-1", "firstName" => "Jason", "lastName" => "Andres", "email" => "jason@example.com", "role" => "Admin Owner" } }
  let(:json_headers) { { "Content-Type" => "application/json" } }
  let(:auth_params) { { tenantId: "winery-1", account: "jwt-token" } }

  before do
    stub_request(:get, "https://api.commerce7.com/v1/account/user")
      .to_return(status: 200, body: user_payload.to_json, headers: json_headers)
  end

  def create_member(customer_id:, club_tier:, status: "Active")
    Current.tenant = tenant
    member = ClubMember.create!(tenant: tenant, commerce7_customer_id: customer_id, club_tier: club_tier, status: status)
    Current.tenant = nil
    member
  end

  describe "GET show" do
    it "renders each active tier with its current color" do
      create_member(customer_id: "cust-1", club_tier: "Red Club")

      get commerce7_settings_path, params: auth_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Red Club")
      expect(response.body).to include(%(value="#{ClubMember::TIER_COLORS[0]}"))
    end

    it "shows an empty state when there are no active tiers" do
      get commerce7_settings_path, params: auth_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No active club tiers yet")
    end

    it "returns 403 for an unknown tenant" do
      get commerce7_settings_path, params: { tenantId: "unknown", account: "jwt-token" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH update" do
    it "persists a valid hex override and redirects with saved=true" do
      create_member(customer_id: "cust-1", club_tier: "Red Club")

      patch commerce7_settings_path, params: auth_params.merge(tier_colors: { "Red Club" => "#123abc" })

      expect(response).to redirect_to(commerce7_settings_path(tenantId: "winery-1", account: "jwt-token", saved: true))
      expect(tenant.reload.tier_color_overrides).to eq({ "Red Club" => "#123abc" })
    end

    it "re-renders with 422 and does not persist an invalid hex" do
      create_member(customer_id: "cust-1", club_tier: "Red Club")

      patch commerce7_settings_path, params: auth_params.merge(tier_colors: { "Red Club" => "nothex" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Enter a valid hex color")
      expect(tenant.reload.tier_color_overrides).to eq({})
    end

    it "clears a previously saved override when submitted blank" do
      create_member(customer_id: "cust-1", club_tier: "Red Club")
      tenant.update!(tier_color_overrides: { "Red Club" => "#123abc" })

      patch commerce7_settings_path, params: auth_params.merge(tier_colors: { "Red Club" => "" })

      expect(tenant.reload.tier_color_overrides).to eq({})
    end

    it "ignores a submitted color for a tier outside the current breakdown" do
      create_member(customer_id: "cust-1", club_tier: "Red Club")

      patch commerce7_settings_path, params: auth_params.merge(tier_colors: { "Ghost Club" => "#123abc" })

      expect(tenant.reload.tier_color_overrides).to eq({})
    end

    it "returns 403 for an unknown tenant" do
      patch commerce7_settings_path, params: { tenantId: "unknown", account: "jwt-token" }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
