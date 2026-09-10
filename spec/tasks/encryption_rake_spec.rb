require "rails_helper"
require "rake"

RSpec.describe "encryption:encrypt_existing_pii", type: :task do
  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task["encryption:encrypt_existing_pii"].reenable
    ActiveRecord::Encryption.config.support_unencrypted_data = true
  end

  after do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
  end

  def write_plaintext(table:, id:, column:, value:)
    ActiveRecord::Base.connection.execute(
      "UPDATE #{table} SET #{column} = #{ActiveRecord::Base.connection.quote(value)} WHERE id = #{id}"
    )
  end

  def raw_column(table:, id:, column:)
    ActiveRecord::Base.connection.select_value("SELECT #{column} FROM #{table} WHERE id = #{id}")
  end

  it "encrypts a pre-existing plaintext Tenant#raw_activation_payload" do
    tenant = Tenant.create!(commerce7_tenant_id: "legacy-tenant")
    write_plaintext(table: "tenants", id: tenant.id, column: "raw_activation_payload", value: '{"email":"legacy@example.com"}')
    expect(raw_column(table: "tenants", id: tenant.id, column: "raw_activation_payload")).to include("legacy@example.com")

    Rake::Task["encryption:encrypt_existing_pii"].invoke

    expect(raw_column(table: "tenants", id: tenant.id, column: "raw_activation_payload")).not_to include("legacy@example.com")
    expect(Tenant.unscoped.find(tenant.id).raw_activation_payload).to eq({ "email" => "legacy@example.com" })
  end

  it "encrypts a pre-existing plaintext ClubMember#name and #email" do
    tenant = Tenant.create!(commerce7_tenant_id: "legacy-tenant-2")
    Current.tenant = tenant
    member = ClubMember.create!(tenant: tenant, commerce7_customer_id: "legacy-cust")
    Current.tenant = nil
    write_plaintext(table: "club_members", id: member.id, column: "name", value: "Legacy Name")
    write_plaintext(table: "club_members", id: member.id, column: "email", value: "legacy@example.com")

    Rake::Task["encryption:encrypt_existing_pii"].invoke

    expect(raw_column(table: "club_members", id: member.id, column: "name")).not_to eq("Legacy Name")
    expect(raw_column(table: "club_members", id: member.id, column: "email")).not_to eq("legacy@example.com")
    Current.tenant = tenant
    reloaded = ClubMember.unscoped.find(member.id)
    expect(reloaded.name).to eq("Legacy Name")
    expect(reloaded.email).to eq("legacy@example.com")
    Current.tenant = nil
  end

  it "is a no-op for a tenant with no activation payload" do
    Tenant.create!(commerce7_tenant_id: "no-payload-tenant")

    expect { Rake::Task["encryption:encrypt_existing_pii"].invoke }.not_to raise_error
  end

  it "is a no-op for a club member with no name or email" do
    tenant = Tenant.create!(commerce7_tenant_id: "no-pii-tenant")
    Current.tenant = tenant
    ClubMember.create!(tenant: tenant, commerce7_customer_id: "no-pii-cust")
    Current.tenant = nil

    expect { Rake::Task["encryption:encrypt_existing_pii"].invoke }.not_to raise_error
  end
end
