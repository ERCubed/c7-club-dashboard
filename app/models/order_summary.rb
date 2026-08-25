class OrderSummary < ApplicationRecord
  include TenantScoped

  belongs_to :club_member, foreign_key: :commerce7_customer_id, primary_key: :commerce7_customer_id, inverse_of: :order_summary, optional: true

  validates :commerce7_customer_id, presence: true, uniqueness: { scope: :tenant_id }
  validates :order_count, numericality: { greater_than_or_equal_to: 0 }
  validates :lifetime_value_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
