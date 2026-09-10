module Commerce7
  # Receives Commerce7's Web Hooks — configured once, app-wide, in the
  # Developer Center's app version under "Step 1. APIs & Webhooks", NOT
  # per-tenant. Per Commerce7's docs (developer.commerce7.com/docs/
  # app-apis-webhooks), a webhook registered there applies automatically to
  # every tenant that installs the app, no per-winery setup required — this
  # is a different, app-level mechanism from a store's own independent
  # "Developer > Web Hooks" admin page (documentation.commerce7.com/
  # configuring-your-webhook), which is for a winery's own integrations,
  # unrelated to marketplace apps like this one. Per Commerce7's docs
  # (developer.commerce7.com/docs/webhooks), the body is {object, action,
  # payload, user, tenantId}; object/action cover far more than we act on
  # (Order, Product, Tag, ...), so anything we don't recognize is silently
  # a no-op rather than an error.
  #
  # Create/Update for Club Membership re-triggers Commerce7::SyncJob scoped
  # to just that tenant rather than upserting straight from this payload:
  # whether "payload" for a Club Membership event embeds the same nested
  # customer/club sub-objects the bulk GET /club-membership list endpoint
  # does, or just raw foreign keys, isn't documented anywhere we've found.
  # Trusting a thinner shape could silently null out a previously-synced
  # name/email/tier; re-running the already-proven bulk sync for one tenant
  # avoids that risk entirely, at the cost of one extra API list call per
  # event. Delete only needs payload.customerId, which any reasonable
  # shape is expected to carry regardless of that open question.
  #
  # Every handler here is naturally idempotent — re-upserting or re-deleting
  # the same record twice ends at the same state — since Commerce7 doesn't
  # document a delivery/event id to dedupe against in the first place.
  class WebhooksController < BaseController
    # `action` is also the name Rails reserves for the controller action
    # itself (routing sets params[:action] = "create" on every request
    # regardless of body content) — reading it via `params` would silently
    # return "create" no matter what Commerce7 actually sent, matching
    # none of the "Create"/"Update"/"Delete" branches below and turning
    # every webhook into a silent no-op. Parsing the raw JSON body instead
    # sidesteps that collision entirely.
    def create
      body = JSON.parse(request.body.read)
      return head :bad_request unless body["tenantId"].present? && body["object"].present? && body["action"].present?

      tenant = Tenant.active.find_by(commerce7_tenant_id: body["tenantId"])
      handle(tenant, object: body["object"], action: body["action"], payload: body["payload"] || {}) if tenant

      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def handle(tenant, object:, action:, payload:)
      case object
      when "Club Membership"
        case action
        when "Create", "Update" then Commerce7::SyncJob.perform_later(tenant)
        when "Delete" then remove_member(tenant, payload["customerId"])
        end
      when "Customer"
        remove_member(tenant, payload["customerId"]) if action == "Delete"
      end
    end

    def remove_member(tenant, customer_id)
      return if customer_id.blank?

      Current.tenant = tenant
      ClubMember.find_by(commerce7_customer_id: customer_id)&.destroy
      OrderSummary.find_by(commerce7_customer_id: customer_id)&.destroy
    ensure
      Current.tenant = nil
    end
  end
end
