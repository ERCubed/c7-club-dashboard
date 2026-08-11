class ClubMember < ApplicationRecord
  include TenantScoped

  validates :commerce7_customer_id, presence: true, uniqueness: { scope: :tenant_id }
end
