module Commerce7
  # Recurring job (see config/recurring.yml) that keeps AuditEvent from
  # growing unbounded — deletes anything past AuditEvent::RETENTION_DAYS.
  class PurgeExpiredAuditEventsJob < ApplicationJob
    queue_as :default

    def perform
      AuditEvent.expired.in_batches.delete_all
    end
  end
end
