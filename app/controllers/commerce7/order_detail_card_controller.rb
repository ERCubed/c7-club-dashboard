module Commerce7
  # Tab Menu extension on Commerce7's Order Detail page (there is no Customer
  # Detail placement — see club-dashboard-plan.md): a compact club membership
  # summary for the order's customer. Reads only what Commerce7::SyncJob
  # already synced, no live Commerce7 calls from this page.
  #
  # Commerce7's docs don't publish the exact param name context extensions
  # receive beyond tenantId/account — their own example uses "customerId"
  # generically, not tied to a specific placement — so this reads
  # params[:customerId] until that's confirmed against a real embed.
  class OrderDetailCardController < ExtensionController
    AT_RISK_MONTHS = 6

    def show
      customer_id = params[:customerId]
      @member = customer_id.present? ? ClubMember.includes(:order_summary).find_by(commerce7_customer_id: customer_id) : nil
      @at_risk = @member.present? && @member.status == "Active" && at_risk?(@member.order_summary)
      @at_risk_months = AT_RISK_MONTHS
    end

    private

    def at_risk?(order_summary)
      order_summary.nil? || order_summary.last_order_at.nil? || order_summary.last_order_at < AT_RISK_MONTHS.months.ago
    end
  end
end
