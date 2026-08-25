class ClubMember < ApplicationRecord
  include TenantScoped

  # Joined on the Commerce7 customer id rather than a real foreign key — both
  # tables are populated independently from the same sync (Commerce7::SyncJob)
  # and neither owns the other.
  has_one :order_summary, foreign_key: :commerce7_customer_id, primary_key: :commerce7_customer_id, inverse_of: :club_member

  validates :commerce7_customer_id, presence: true, uniqueness: { scope: :tenant_id }

  scope :active, -> { where(status: "Active") }
end
