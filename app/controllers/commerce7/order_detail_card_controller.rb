module Commerce7
  # Tab Menu extension on Commerce7's Order Detail page (there is no Customer
  # Detail placement — see club-dashboard-plan.md): a compact club membership
  # summary for the order's customer.
  #
  # Confirmed via a real trial-winery embed that Commerce7 sends `orderId`
  # here, not `customerId` (see club-dashboard-plan.md) — we don't sync
  # order-to-customer mappings, so this makes one live API call per page
  # view to resolve the order's customerId before reading the locally
  # synced ClubMember/OrderSummary data.
  class OrderDetailCardController < ExtensionController
    layout "commerce7_extension"

    def show
      order_id = params[:orderId]
      @member = order_id.present? ? find_member(order_id) : nil
      @at_risk = @member&.at_risk? || false
      @at_risk_months = ClubMember::DEFAULT_AT_RISK_MONTHS
    end

    private

    def find_member(order_id)
      customer_id = Commerce7::Client.new(Current.tenant).fetch_order(order_id)["customerId"]
      return nil if customer_id.blank?

      ClubMember.includes(:order_summary).find_by(commerce7_customer_id: customer_id)
    rescue Commerce7::Client::Error => e
      Rails.logger.error("Commerce7 order lookup failed for order #{order_id}: #{e.message}")
      nil
    end
  end
end
