class OrderSummary < ApplicationRecord
  include TenantScoped

  validates :commerce7_customer_id, presence: true, uniqueness: { scope: :tenant_id }
  validates :order_count, numericality: { greater_than_or_equal_to: 0 }
  validates :lifetime_value_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
