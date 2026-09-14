class Tenant < ApplicationRecord
  include Commerce7::TenantConcern

  # Per Commerce7's activation docs, this jsonb blob carries the installing
  # staff member's first name, last name, and email — PII, encrypted at
  # rest even though it's write-once and never queried by value.
  encrypts :raw_activation_payload

  has_many :club_members, dependent: :destroy
  has_many :order_summaries, dependent: :destroy

  validate :tier_color_overrides_are_valid_hex

  private

  def tier_color_overrides_are_valid_hex
    tier_color_overrides.each do |tier, hex|
      errors.add(:tier_color_overrides, "#{tier.inspect} must be a 6-digit hex color") unless hex.to_s.match?(/\A#[0-9a-fA-F]{6}\z/)
    end
  end
end
