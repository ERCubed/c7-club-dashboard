require "rails_helper"

RSpec.describe Commerce7::PurgeExpiredAuditEventsJob do
  it "deletes audit events past the retention window" do
    expired = AuditEvent.create!(event_type: "test_event", success: true, created_at: (AuditEvent::RETENTION_DAYS + 1).days.ago)

    described_class.perform_now

    expect(AuditEvent.exists?(expired.id)).to be false
  end

  it "leaves audit events still inside the retention window" do
    recent = AuditEvent.create!(event_type: "test_event", success: true, created_at: (AuditEvent::RETENTION_DAYS - 1).days.ago)

    described_class.perform_now

    expect(AuditEvent.exists?(recent.id)).to be true
  end
end
