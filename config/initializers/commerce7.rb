Commerce7.configure do |c|
  c.tenant_class_name = "Tenant"

  c.webhook_credentials = -> {
    [
      Rails.application.credentials.dig(:commerce7, :webhook_username),
      Rails.application.credentials.dig(:commerce7, :webhook_password)
    ]
  }

  c.app_credentials = -> {
    [
      Rails.application.credentials.dig(:commerce7, :app_id),
      Rails.application.credentials.dig(:commerce7, :app_secret_key)
    ]
  }

  c.audit = ->(**kwargs) { AuditEvent.record!(**kwargs) }
end

# Backfill: Commerce7's Web Hooks (see below) only fire on future changes,
# not a newly (re)installed tenant's pre-existing club memberships — this
# one-time sync is what actually populates those.
Commerce7.on_activate do |tenant, _payload|
  Commerce7::SyncJob.perform_later(tenant)
end

# Commerce7's Web Hooks feature — registered once, app-wide, in the
# Developer Center (Step 1. APIs & Webhooks on this app's version), and
# applied automatically to every tenant that installs the app.
#
# Create/Update for Club Membership re-triggers Commerce7::SyncJob scoped
# to just that tenant rather than upserting straight from the webhook
# payload: whether "payload" for a Club Membership event embeds the same
# nested customer/club sub-objects the bulk GET /club-membership list
# endpoint does, or just raw foreign keys, isn't documented anywhere we've
# found. Trusting a thinner shape could silently null out a previously-
# synced name/email/tier; re-running the already-proven bulk sync for one
# tenant avoids that risk entirely, at the cost of one extra API list call
# per event.
Commerce7::Webhooks.on("Club Membership", "Create", "Update") do |tenant, _payload, _actor|
  Commerce7::SyncJob.perform_later(tenant)
end

# Delete only needs payload.customerId, which any reasonable payload shape
# is expected to carry regardless of the open question above. Naturally
# idempotent — re-deleting an already-gone record ends at the same state.
remove_member = lambda do |tenant, customer_id|
  next if customer_id.blank?

  begin
    Current.tenant = tenant
    ClubMember.find_by(commerce7_customer_id: customer_id)&.destroy
    OrderSummary.find_by(commerce7_customer_id: customer_id)&.destroy
    TenantMetricSnapshot.capture!(tenant)
  ensure
    Current.tenant = nil
  end
end

Commerce7::Webhooks.on("Club Membership", "Delete") do |tenant, payload, _actor|
  remove_member.call(tenant, payload["customerId"])
end

Commerce7::Webhooks.on("Customer", "Delete") do |tenant, payload, _actor|
  remove_member.call(tenant, payload["customerId"])
end
