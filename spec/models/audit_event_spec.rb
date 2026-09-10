require "rails_helper"

RSpec.describe AuditEvent, type: :model do
  it "requires an event_type" do
    event = AuditEvent.new(success: true)

    expect(event).not_to be_valid
    expect(event.errors[:event_type]).to be_present
  end

  it "requires success to be true or false, not nil" do
    event = AuditEvent.new(event_type: "test_event", success: nil)

    expect(event).not_to be_valid
    expect(event.errors[:success]).to be_present
  end

  describe "encryption" do
    it "stores actor and origin_ip as ciphertext at rest, but still queryable by exact value" do
      event = AuditEvent.create!(event_type: "test_event", success: true, actor: "jane@example.com", origin_ip: "1.2.3.4")

      raw_actor, raw_ip = ActiveRecord::Base.connection.select_rows(
        "SELECT actor, origin_ip FROM audit_events WHERE id = #{event.id}"
      ).first

      expect(raw_actor).not_to include("jane@example.com")
      expect(raw_ip).not_to eq("1.2.3.4")
      expect(AuditEvent.find_by(actor: "jane@example.com", origin_ip: "1.2.3.4")).to eq(event)
    end
  end

  describe ".expired" do
    it "includes events past RETENTION_DAYS and excludes recent ones" do
      old = AuditEvent.create!(event_type: "test_event", success: true, created_at: (AuditEvent::RETENTION_DAYS + 1).days.ago)
      recent = AuditEvent.create!(event_type: "test_event", success: true, created_at: 1.day.ago)

      expect(AuditEvent.expired).to contain_exactly(old)
      expect(AuditEvent.expired).not_to include(recent)
    end
  end

  describe ".record!" do
    it "creates an event with the given attributes" do
      AuditEvent.record!(event_type: "test_event", success: true, actor: "jane@example.com", commerce7_tenant_id: "winery-1", origin_ip: "1.2.3.4", metadata: { foo: "bar" })

      event = AuditEvent.last
      expect(event.event_type).to eq("test_event")
      expect(event.success).to be true
      expect(event.actor).to eq("jane@example.com")
      expect(event.commerce7_tenant_id).to eq("winery-1")
      expect(event.origin_ip).to eq("1.2.3.4")
      expect(event.metadata).to eq({ "foo" => "bar" })
    end

    it "logs and does not raise when the record is invalid, rather than breaking the caller" do
      expect(Rails.logger).to receive(:error).with(/invalid_event/)

      expect {
        AuditEvent.record!(event_type: "invalid_event", success: nil)
      }.not_to raise_error

      expect(AuditEvent.find_by(event_type: "invalid_event")).to be_nil
    end
  end
end
