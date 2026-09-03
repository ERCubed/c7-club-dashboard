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
- Kamal for deployment, on a DigitalOcean Droplet

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
  app_id: ...
  app_secret_key: ...
  # a single App ID/App Secret Key pair for the app as a whole (not
  # per-tenant), from Commerce7's dev center — used by Commerce7::Client
  # to authenticate REST calls; the `tenant` header scopes each request
  # to a specific winery
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

Deployed via [Kamal](https://kamal-deploy.org) (`config/deploy.yml`) to a DigitalOcean
Droplet, at `https://club-dashboard.cellarratdevelopment.com`. `kamal-proxy` terminates
SSL (Let's Encrypt) and routes by subdomain, so the same Droplet can host multiple
Commerce7 apps side by side — each as its own Kamal service on its own subdomain, rather
than one combined app. Postgres runs as a Kamal accessory on the same Droplet, not a
managed database add-on. Images are pushed to `ghcr.io` as `ercubed/c7_club_dashboard`
(lowercase, even though the GitHub username is mixed-case).

GitHub Actions (`.github/workflows/deploy.yml`) deploys automatically on every push to
`main`, using a dedicated deploy-only SSH key (no passphrase, separate from any
developer's personal key) stored as the `KAMAL_DEPLOY_SSH_KEY` repo secret.

To deploy manually:

```
bin/kamal deploy
```

Useful aliases (see `config/deploy.yml`):

```
bin/kamal console  # Rails console on the server
bin/kamal shell     # shell in the app container
bin/kamal logs      # tail app logs
bin/kamal dbc       # Postgres console
```

Note: Kamal builds from the last git **commit**, not the working tree — uncommitted
changes to `config/deploy.yml`, `config/database.yml`, etc. won't make it into the
image. Commit before deploying.
