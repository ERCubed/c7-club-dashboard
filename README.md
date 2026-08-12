# Club Member Dashboard for Commerce7

A read-only admin dashboard, embedded as a Commerce7 iframe extension, that gives winery
staff a quick read on club health: top spenders, members at risk of lapsing, and tier
breakdowns. Built multi-tenant from the start, even though a single trial winery is the
initial target.

## Stack

- Ruby 3.4.10, Rails 8.1
- Postgres
- Hotwire (Turbo + Stimulus) with importmap, no Node/JS bundler
- Tailwind CSS (via `tailwindcss-rails`, no Node required)
- Solid Queue / Solid Cache / Solid Cable (Postgres-backed, no Redis)
- RSpec, with a SimpleCov gate requiring 100% line and branch coverage
- Kamal for deployment (target host not yet decided)

## Setup

```
bin/setup
```

Or manually:

```
bundle install
bin/rails db:prepare
```

You'll also need two things in Rails credentials (`bin/rails credentials:edit`) before
the app can encrypt tenant data or authenticate Commerce7's webhooks:

```yaml
active_record_encryption:
  primary_key: ...
  deterministic_key: ...
  key_derivation_salt: ...
  # generate with: bin/rails db:encryption:init

commerce7:
  webhook_username: ...
  webhook_password: ...
  # shared secret you also configure in Commerce7's app dashboard,
  # under the Install/Uninstall URLs' "Advanced" section
```

## Running the app

```
bin/dev
```

Starts Puma and the Tailwind watcher via `Procfile.dev`. Solid Queue doesn't run
in-process unless `SOLID_QUEUE_IN_PUMA` is set (see `config/puma.rb`); run `bin/jobs`
separately if you need it — moot for now, since there's no job to run yet.

## Running tests

```
bundle exec rspec
```

Coverage report is written to `coverage/index.html` (gitignored). The suite fails if
line or branch coverage drops below 100%.

```
bin/rubocop
bin/brakeman
```

## Multi-tenancy

Every tenant-scoped model (`ClubMember`, `OrderSummary`) includes the `TenantScoped`
concern, which applies a `default_scope` keyed off `Current.tenant`. If `Current.tenant`
isn't set, scoped queries return nothing rather than every tenant's data — deliberate,
since a missed scope is exactly how tenant data leaks in a shared-table design. Code
that needs to operate across tenants (e.g. the sync job) must set `Current.tenant`
explicitly for each tenant it processes.

## Commerce7 integration

- `POST /commerce7/activate` / `POST /commerce7/deactivate` — install/uninstall
  webhooks, secured with HTTP Basic Auth (see credentials above). Deactivation
  soft-deactivates a `Tenant`, never deletes it.
- `Commerce7::Client` (`app/services/commerce7/client.rb`) — REST API client for
  customers, club memberships, and orders. Handles pagination and 429 rate-limit
  backoff.

## Deployment

Not yet decided — Kamal is configured (`config/deploy.yml`) but no target host is set.
