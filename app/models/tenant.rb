class Tenant < ApplicationRecord
  has_many :club_members, dependent: :destroy
  has_many :order_summaries, dependent: :destroy

  validates :commerce7_tenant_id, presence: true, uniqueness: true
  validate :tier_color_overrides_are_valid_hex

  scope :active, -> { where(deactivated_at: nil) }

  # Handles both first install and a reinstall of a previously deactivated
  # tenant (find_or_initialize_by, not create!) — activation always clears
  # deactivated_at, matching Commerce7 sending an activation POST either way.
  def self.activate!(commerce7_tenant_id:, payload:)
    tenant = find_or_initialize_by(commerce7_tenant_id: commerce7_tenant_id)
    tenant.update!(activated_at: Time.current, deactivated_at: nil, raw_activation_payload: payload)
    tenant
  end

  def active?
    deactivated_at.nil?
  end

  # Soft-deactivates, never deletes — an uninstall may be followed by a
  # reinstall (see .activate!), and synced ClubMember/OrderSummary data
  # shouldn't vanish just because the app was temporarily removed.
  def deactivate!
    update!(deactivated_at: Time.current)
  end

  private

  def tier_color_overrides_are_valid_hex
    tier_color_overrides.each do |tier, hex|
      errors.add(:tier_color_overrides, "#{tier.inspect} must be a 6-digit hex color") unless hex.to_s.match?(/\A#[0-9a-fA-F]{6}\z/)
    end
  end
end
