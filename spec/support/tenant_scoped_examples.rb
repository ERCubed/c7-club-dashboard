RSpec.shared_examples "a tenant scoped model" do
  let(:tenant_a) { Tenant.create!(commerce7_tenant_id: "tenant-a") }
  let(:tenant_b) { Tenant.create!(commerce7_tenant_id: "tenant-b") }

  it "only returns records for Current.tenant" do
    record_a = create_record.call(tenant_a)
    create_record.call(tenant_b)

    Current.tenant = tenant_a

    expect(described_class.all).to contain_exactly(record_a)
  end

  it "returns nothing when Current.tenant is unset" do
    create_record.call(tenant_a)

    Current.tenant = nil

    expect(described_class.all).to be_empty
  end

  it "does not return another tenant's record by id" do
    other_record = create_record.call(tenant_b)

    Current.tenant = tenant_a

    expect(described_class.find_by(id: other_record.id)).to be_nil
  end
end
