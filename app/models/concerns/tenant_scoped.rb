module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :tenant

    # Fail safe rather than fail open: with no Current.tenant set, scoped
    # queries return nothing instead of every tenant's data. Callers that
    # need to operate across tenants (e.g. the sync job) must do so
    # explicitly via `.unscoped` while setting Current.tenant per tenant.
    default_scope { Current.tenant ? where(tenant_id: Current.tenant.id) : none }
  end
end
