module Commerce7
  # Recurring job (see config/recurring.yml) that refreshes ClubMember and
  # OrderSummary for every active tenant.
  #
  # Pulls only GET /club-membership: each record embeds the full customer
  # object (name, email, orderInformation) and the full club object (title),
  # confirmed against Commerce7's docs, so this one paginated endpoint covers
  # both tables without separate calls to /customer or /order — worth it
  # under the 100 req/min per-tenant limit.
  class SyncJob < ApplicationJob
    queue_as :default

    def perform
      Tenant.active.find_each { |tenant| sync_tenant(tenant) }
    end

    private

    def sync_tenant(tenant)
      Current.tenant = tenant
      primary_memberships_by_customer(tenant).each_value { |membership| upsert(tenant, membership) }
    rescue Commerce7::Client::Error => e
      Rails.logger.error("Commerce7 sync failed for tenant #{tenant.commerce7_tenant_id}: #{e.message}")
    ensure
      Current.tenant = nil
    end

    # A customer can hold more than one club membership (e.g. Red Club and
    # White Club), but ClubMember has one row per customer. Keep whichever
    # membership matches Commerce7's own "current club" designation
    # (customer.orderInformation.currentClubTitle); fall back to the first
    # membership seen if none matches.
    def primary_memberships_by_customer(tenant)
      memberships = {}

      Commerce7::Client.new(tenant).each_club_membership do |membership|
        customer_id = membership["customerId"]
        current = memberships[customer_id]
        memberships[customer_id] = membership if current.nil? || (current_club?(membership) && !current_club?(current))
      end

      memberships
    end

    def current_club?(membership)
      customer = membership["customer"] || {}
      club = membership["club"] || {}
      club["title"].present? && club["title"] == customer.dig("orderInformation", "currentClubTitle")
    end

    def upsert(tenant, membership)
      customer = membership["customer"] || {}
      club = membership["club"] || {}
      order_info = customer["orderInformation"] || {}
      customer_id = membership["customerId"]

      ClubMember.find_or_initialize_by(tenant: tenant, commerce7_customer_id: customer_id).update!(
        name: [ customer["firstName"], customer["lastName"] ].compact.join(" ").presence,
        email: customer.dig("emails", 0, "email"),
        club_tier: club["title"],
        joined_at: membership["signupDate"],
        status: membership["status"]
      )

      OrderSummary.find_or_initialize_by(tenant: tenant, commerce7_customer_id: customer_id).update!(
        last_order_at: order_info["lastOrderDate"],
        lifetime_value_cents: order_info["lifetimeValue"] || 0,
        order_count: order_info["orderCount"] || 0
      )
    end
  end
end
