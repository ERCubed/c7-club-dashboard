class TenantMetricSnapshot < ApplicationRecord
  include TenantScoped

  validates :snapshot_date, presence: true, uniqueness: { scope: :tenant_id }

  scope :recent, ->(days = 90) { where(snapshot_date: days.days.ago.to_date..).order(:snapshot_date) }
end
