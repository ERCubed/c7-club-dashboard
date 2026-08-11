class Tenant < ApplicationRecord
  encrypts :api_key
  encrypts :api_secret

  has_many :club_members, dependent: :destroy
  has_many :order_summaries, dependent: :destroy

  validates :commerce7_tenant_id, presence: true, uniqueness: true

  scope :active, -> { where(deactivated_at: nil) }

  def active?
    deactivated_at.nil?
  end
end
