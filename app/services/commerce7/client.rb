module Commerce7
  # HTTP client for Commerce7's REST API. Confirmed against Commerce7's public
  # docs: base URL, Basic Auth (App ID/App Secret Key as user/pass), endpoint
  # paths, page/limit pagination (max 50/page, matches PAGE_SIZE), response
  # envelope keys, and the 100 req/min rate limit.
  #
  # Still unresolved: whether the App ID/Secret Key pair is unique per tenant
  # (what `tenant.api_key`/`api_secret` assumes) or a single pair shared
  # across every tenant that installs the app — the docs describe it as
  # created once "for your app," which reads as possibly global. The `tenant`
  # header below is sent defensively; it's confirmed required for the
  # separate staff-identity endpoint, but docs don't say whether standard
  # resource endpoints need it too. Confirm both before relying on this for
  # real tenant data.
  class Client
    class Error < StandardError; end
    class AuthenticationError < Error; end
    class RateLimitedError < Error; end
    class ApiError < Error; end

    # Trailing slash matters: Faraday/URI joins a relative path onto this by
    # RFC 3986 merge rules, so without it "v1" gets treated as a filename and
    # dropped (e.g. base ".../v1" + "customer" => ".../customer", not ".../v1/customer").
    BASE_URL = "https://api.commerce7.com/v1/".freeze
    PAGE_SIZE = 50
    MAX_RETRIES = 3

    def initialize(tenant, base_url: BASE_URL, sleeper: ->(seconds) { sleep(seconds) })
      if tenant.api_key.blank? || tenant.api_secret.blank?
        raise ArgumentError, "tenant is missing Commerce7 API credentials"
      end

      @tenant = tenant
      @base_url = base_url
      @sleeper = sleeper
    end

    def each_customer(&block)
      return enum_for(:each_customer) unless block_given?

      each_record("customer", "customers", &block)
    end

    def each_club_membership(&block)
      return enum_for(:each_club_membership) unless block_given?

      each_record("club-membership", "clubMemberships", &block)
    end

    def each_order(&block)
      return enum_for(:each_order) unless block_given?

      each_record("order", "orders", &block)
    end

    private

    attr_reader :tenant, :base_url, :sleeper

    def each_record(path, response_key)
      page = 1

      loop do
        records = get(path, page: page, limit: PAGE_SIZE)[response_key] || []
        records.each { |record| yield record }

        break if records.size < PAGE_SIZE

        page += 1
      end
    end

    def get(path, params)
      response = with_rate_limit_retry { connection.get(path, params) }
      handle_response(response)
    end

    def with_rate_limit_retry
      attempt = 0

      loop do
        response = yield
        return response unless response.status == 429

        attempt += 1
        if attempt > MAX_RETRIES
          raise RateLimitedError, "Commerce7 rate limit exceeded after #{MAX_RETRIES} retries"
        end

        sleeper.call(retry_delay(response, attempt))
      end
    end

    def retry_delay(response, attempt)
      retry_after = response.headers["retry-after"].to_s.to_i
      retry_after.positive? ? retry_after : 2**attempt
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 401
        raise AuthenticationError, "Commerce7 rejected the tenant's credentials"
      else
        raise ApiError, "Commerce7 API error (#{response.status}): #{response.body}"
      end
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.request :authorization, :basic, tenant.api_key, tenant.api_secret
        f.headers["tenant"] = tenant.commerce7_tenant_id
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end
  end
end
