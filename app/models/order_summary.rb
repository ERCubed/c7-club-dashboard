class OrderSummary < ApplicationRecord
  include TenantScoped

  validates :commerce7_customer_id, presence: true, uniqueness: { scope: :tenant_id }
  validates :order_count, numericality: { greater_than_or_equal_to: 0 }
  validates :lifetime_value, numericality: { greater_than_or_equal_to: 0 }
end
