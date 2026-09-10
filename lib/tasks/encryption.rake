namespace :encryption do
  desc "Re-save existing rows so plaintext ClubMember#name/#email and Tenant#raw_activation_payload get encrypted"
  task encrypt_existing_pii: :environment do
    # A plain `save!` is a no-op here: the decrypted value hasn't changed, so
    # ActiveRecord's dirty tracking sees nothing to write and skips the
    # column entirely, leaving old plaintext rows plaintext forever. Forcing
    # `_will_change!` marks it dirty regardless, so the encrypted type gets a
    # chance to re-serialize (and thus encrypt) it on write. Safe to re-run —
    # already-encrypted rows just get re-encrypted with the same key.
    Tenant.unscoped.find_each do |tenant|
      next if tenant.raw_activation_payload.blank?

      tenant.raw_activation_payload_will_change!
      tenant.save!
    end

    ClubMember.unscoped.find_each do |member|
      next if member.name.blank? && member.email.blank?

      Current.tenant = member.tenant
      member.name_will_change!
      member.email_will_change!
      member.save!
    end
    Current.tenant = nil

    puts "Done."
  end
end
