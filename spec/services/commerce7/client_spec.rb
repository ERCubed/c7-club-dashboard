require "rails_helper"

RSpec.describe Commerce7::Client do
  let!(:app_id) { Rails.application.credentials.dig(:commerce7, :app_id) }
  let!(:app_secret_key) { Rails.application.credentials.dig(:commerce7, :app_secret_key) }
  let(:tenant) { Tenant.create!(commerce7_tenant_id: "winery-1") }
  let(:client) { described_class.new(tenant, sleeper: ->(seconds) { }) }
  let(:json_headers) { { "Content-Type" => "application/json" } }

  describe "#initialize" do
    it "raises when the app id is not configured" do
      allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :app_id).and_return(nil)
      allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :app_secret_key).and_return(app_secret_key)

      expect { described_class.new(tenant) }.to raise_error(ArgumentError)
    end

    it "raises when the app secret key is not configured" do
      allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :app_id).and_return(app_id)
      allow(Rails.application.credentials).to receive(:dig).with(:commerce7, :app_secret_key).and_return(nil)

      expect { described_class.new(tenant) }.to raise_error(ArgumentError)
    end
  end

  describe "#each_customer" do
    include_examples "a Commerce7 paginated resource", method: :each_customer, path: "/customer", response_key: "customers"
  end

  describe "#each_club_membership" do
    include_examples "a Commerce7 paginated resource", method: :each_club_membership, path: "/club-membership", response_key: "clubMemberships"
  end

  describe "#each_order" do
    include_examples "a Commerce7 paginated resource", method: :each_order, path: "/order", response_key: "orders"
  end

  describe "authentication" do
    it "sends HTTP Basic auth and the tenant header" do
      stub = stub_request(:get, "https://api.commerce7.com/v1/customer")
        .with(basic_auth: [ app_id, app_secret_key ], headers: { "tenant" => "winery-1" }, query: hash_including("page" => "1"))
        .to_return(status: 200, body: { "customers" => [] }.to_json, headers: json_headers)

      client.each_customer { |record| record }

      expect(stub).to have_been_requested
    end

    it "raises AuthenticationError on a 401" do
      stub_request(:get, "https://api.commerce7.com/v1/customer")
        .with(query: hash_including("page" => "1"))
        .to_return(status: 401, body: { "message" => "unauthorized" }.to_json, headers: json_headers)

      expect { client.each_customer { |record| record } }.to raise_error(Commerce7::Client::AuthenticationError)
    end
  end

  describe "rate limiting" do
    it "retries using the Retry-After header and then succeeds" do
      stub_request(:get, "https://api.commerce7.com/v1/customer")
        .with(query: hash_including("page" => "1"))
        .to_return(
          { status: 429, headers: { "Retry-After" => "1" } },
          { status: 200, body: { "customers" => [] }.to_json, headers: json_headers }
        )

      results = []
      client.each_customer { |record| results << record }

      expect(results).to eq([])
    end

    it "falls back to exponential backoff when Retry-After is absent" do
      stub_request(:get, "https://api.commerce7.com/v1/customer")
        .with(query: hash_including("page" => "1"))
        .to_return(
          { status: 429 },
          { status: 200, body: { "customers" => [] }.to_json, headers: json_headers }
        )

      expect { client.each_customer { |record| record } }.not_to raise_error
    end

    it "raises RateLimitedError after exhausting retries" do
      stub_request(:get, "https://api.commerce7.com/v1/customer")
        .with(query: hash_including("page" => "1"))
        .to_return(status: 429)

      expect { client.each_customer { |record| record } }.to raise_error(Commerce7::Client::RateLimitedError)
    end
  end

  describe "other API errors" do
    it "raises ApiError on an unexpected status" do
      stub_request(:get, "https://api.commerce7.com/v1/customer")
        .with(query: hash_including("page" => "1"))
        .to_return(status: 500, body: "boom")

      expect { client.each_customer { |record| record } }.to raise_error(Commerce7::Client::ApiError)
    end
  end
end
