# Club Member Dashboard for Commerce7

An admin dashboard, embedded as a set of Commerce7 App Extensions, that gives winery
staff a quick read on club health: top spenders, members at risk of lapsing, and tier
breakdowns, plus a per-customer summary on the Order Detail page and a Settings tab for
per-tier colors. Built multi-tenant from the start, even though a single trial winery is
the initial target.

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
  # shared secret configured in two places in Commerce7's Developer
  # Center: the Install/Uninstall URLs' "Advanced" section, and the app
  # version's Web Hook "Advanced Authentication" (Step 1. APIs & Webhooks)
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
separately if you need it. Recurring jobs (`config/recurring.yml`) run under whichever
process does — see Recurring jobs below.

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

`AuditEvent` is a deliberate exception: no `Tenant` foreign key, not tenant-scoped. An
audit trail has to survive the tenant it's auditing (see `PurgeDeactivatedTenantsJob`
below) and has to cover events where no tenant was ever resolved in the first place (an
auth attempt against an unrecognized tenant is itself worth recording).

## Commerce7 integration

- `POST /commerce7/activate` / `POST /commerce7/deactivate` — install/uninstall
  callbacks, secured with HTTP Basic Auth (see credentials above). Deactivation
  soft-deactivates a `Tenant`; see Recurring jobs for when it's actually deleted.
- `POST /commerce7/webhooks` (`Commerce7::WebhooksController`) — Commerce7's Web
  Hooks feature, registered once app-wide in the Developer Center's app version
  ("Step 1. APIs & Webhooks"), *not* per-tenant. Handles Club Membership
  Create/Update/Delete and Customer Delete; anything else is a no-op. Same shared
  Basic Auth credential as install/uninstall.
- `GET /commerce7/dashboard` — Reports > Club Report placement, the aggregate
  dashboard.
- `GET /commerce7/order-detail-card` — Tab Menu extension on Order Detail; a
  per-customer club summary. Resolves the customer via a live
  `Commerce7::Client#fetch_order` call using the `orderId` param Commerce7
  actually sends — not `customerId`, despite that being Commerce7's generic docs
  example; confirmed against a real embed.
- `GET`/`PATCH` `/commerce7/settings` — Settings tab extension for per-tier
  colors (`Tenant#tier_color_overrides`).
- `Commerce7::Client` (`app/services/commerce7/client.rb`) — REST API client for
  customers, club memberships, and orders. Handles pagination and 429 rate-limit
  backoff. Needs the app's Developer Center API scopes to actually include
  Orders — missing that scope caused real 401s from `fetch_order` in production
  even though club-membership calls worked fine, since Commerce7 apparently
  scopes access per resource rather than all-or-nothing.

## Recurring jobs

`config/recurring.yml`, run via Solid Queue (in-process under Puma when
`SOLID_QUEUE_IN_PUMA` is set):

- `Commerce7::SyncJob` — daily reconciliation pull of club membership data. Also
  triggered directly (scoped to one tenant) on activation for backfill, and by
  `WebhooksController` on a Club Membership Create/Update event, since webhooks
  only fire on future changes and their payload shape for that event isn't
  confirmed to embed what the sync needs.
- `Commerce7::PurgeDeactivatedTenantsJob` — hard-deletes a `Tenant` (and its
  `ClubMember`/`OrderSummary` rows) 30 days after deactivation, per Commerce7's
  App Security Policy (customer data deleted within 30 days of app
  termination). A reinstall within that window keeps the tenant's data intact.
- `Commerce7::PurgeExpiredAuditEventsJob` — prunes `AuditEvent` rows past
  `AuditEvent::RETENTION_DAYS` (180 days).

## Security

- PII (`ClubMember#name`/`#email`, `Tenant#raw_activation_payload`,
  `AuditEvent#actor`/`#origin_ip`) is encrypted at rest via Rails' Active Record
  Encryption (`encrypts`) — see the `active_record_encryption` credentials above.
- `AuditEvent` records who did what, when, success or failure, and origin IP for
  every security-relevant action (staff auth, settings changes, webhook-driven
  deletions, tenant lifecycle) — retained 180 days, pruned daily.
- See [`docs/incident_response_plan.md`](docs/incident_response_plan.md) for what
  to do if something goes wrong.

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
