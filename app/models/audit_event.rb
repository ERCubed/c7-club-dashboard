class AuditEvent < ApplicationRecord
  # Both are personal data — encrypted at rest per the standing rule (any
  # new PII field gets `encrypts` as part of the same change). Deterministic
  # so an incident investigation can still query by exact actor/IP (e.g.
  # AuditEvent.where(actor: "jane@example.com")) — non-deterministic
  # encryption would make that impossible via SQL.
  encrypts :actor, :origin_ip, deterministic: true

  RETENTION_DAYS = 180

  validates :event_type, presence: true
  validates :success, inclusion: { in: [ true, false ] }

  scope :expired, -> { where(created_at: ...RETENTION_DAYS.days.ago) }

  # Auditing must never be why the thing it's observing fails — a DB hiccup
  # writing an audit row shouldn't 500 a staff member's dashboard load or
  # drop a Commerce7 webhook. Logged loudly on failure so a real bug here
  # (e.g. a missing required field) still surfaces instead of vanishing.
  def self.record!(event_type:, success:, actor: nil, commerce7_tenant_id: nil, origin_ip: nil, metadata: {})
    create!(
      event_type: event_type,
      success: success,
      actor: actor,
      commerce7_tenant_id: commerce7_tenant_id,
      origin_ip: origin_ip,
      metadata: metadata
    )
  rescue => e
    Rails.logger.error("AuditEvent.record! failed for #{event_type.inspect}: #{e.class}: #{e.message}")
  end
end
