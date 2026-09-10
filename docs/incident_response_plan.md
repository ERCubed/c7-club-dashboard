# Incident Response Plan

Covers c7-club-dashboard: a single-tenant-at-launch Commerce7 App Extension, deployed via Kamal to one DigitalOcean droplet (`159.223.183.86`, public host `club-dashboard.cellarratdevelopment.com`), backed by a Postgres accessory on the same droplet.

## 1. Roles and contacts

| Role | Who | Contact |
|---|---|---|
| Primary maintainer / incident owner | Eric Roberts | eric@cellarratdevelopment.com |
| App/team contact | — | admin@cellarratdevelopment.com |
| Commerce7 (platform partner) | Commerce7 support | support@commerce7.com |
| Infrastructure provider | DigitalOcean | via DO support console on the account owning the droplet |
| Source control / CI | GitHub (ERCubed/c7-club-dashboard) | via GitHub support if account-level compromise is suspected |

Commerce7's App Security Policy requires notifying Commerce7 **within 4 hours** of a security incident, data breach, or critical vulnerability. That clock starts at detection, not at containment — notify Commerce7 in parallel with containment work, not after.

## 2. What counts as an incident

- Unauthorized access to production data (`ClubMember`/`OrderSummary`/`Tenant` rows, all of which hold or are keyed to customer PII).
- A leaked or suspected-leaked credential: the Commerce7 App ID/Secret Key, the shared webhook Basic Auth username/password, `RAILS_MASTER_KEY`, the Postgres password, or the droplet's SSH keys.
- Unexpected/unauthorized SSH or `docker exec` access to the droplet.
- A deploy to `main` that didn't go through PR review (see `AGENTS`/session history — this has happened at least once from tooling error, not malice, but treat any unreviewed prod change as worth checking).
- Anomalous entries in `AuditEvent` — repeated `commerce7_server_auth`/`staff_extension_auth` failures from one origin, a `tier_colors_updated` or webhook-driven deletion event no one on the team recognizes, or a burst of activity at an unusual hour.
- A vulnerability disclosure (from Commerce7, a security researcher, or discovered internally) affecting this app or its dependencies.

## 3. Detection — where to look first

1. **`AuditEvent` table** (added for exactly this purpose — see `app/models/audit_event.rb`). Query by `commerce7_tenant_id`, `event_type`, `actor`, or `origin_ip` (all indexed or deterministically encrypted for exact-match lookup) to reconstruct who did what, when, and whether it succeeded:
   ```
   bin/kamal app exec --interactive --reuse "bin/rails runner 'AuditEvent.where(success: false).order(created_at: :desc).limit(50).each { |e| puts e.attributes }'"
   ```
2. **Container logs** (Rails' default request log + Thruster's structured access log, both on stdout):
   ```
   bin/kamal app logs --grep <pattern>
   ```
   These are ephemeral (Docker's local log driver, no shipping to a durable store) — pull anything relevant into a saved file immediately, don't rely on being able to re-query them later.
3. **GitHub Actions run history** (`https://github.com/ERCubed/c7-club-dashboard/actions`) — confirms what was actually deployed and when, independent of what's in the working tree.
4. **DigitalOcean droplet access** — check the DO control panel's access/audit log if account-level compromise is suspected; the web console (no SSH needed) is the fallback if SSH access itself is in question.

## 4. Containment

Match the response to what's actually compromised — don't rotate everything reflexively, but don't hesitate either once scope is known.

- **Commerce7 App ID/Secret Key leaked or misused**: regenerate the Secret Key in the Commerce7 Developer Center immediately. This is the credential `Commerce7::Client` uses for *every* tenant (App ID/Secret Key is one app-wide pair, not per-tenant — see `app/services/commerce7/client.rb`), so a leak here is a whole-app exposure, not scoped to one winery.
- **Shared webhook Basic Auth credential leaked** (`commerce7.webhook_username`/`webhook_password` — backs Install/Uninstall URLs *and* the Web Hooks registered in the Developer Center's "APIs & Webhooks" step): generate new credentials, update `config/credentials.yml.enc`, update both the Install/Uninstall URL config and the Web Hook's "Advanced Authentication" field in the Developer Center to match, then deploy.
- **`RAILS_MASTER_KEY` leaked**: this decrypts every credential above plus all `encrypts`-protected PII columns. Rotate it (`bin/rails credentials:edit` re-encrypts under a fresh key via the standard Rails rotation flow), update the `RAILS_MASTER_KEY` GitHub Actions secret, and rotate every credential it was protecting, since they must all be treated as exposed too.
- **Droplet-level compromise (SSH/root access)**: revoke the affected key from `~/.ssh/authorized_keys` via the DO web console (doesn't require SSH), rotate `KAMAL_DEPLOY_SSH_KEY` (the GitHub Actions deploy key, separate from personal keys), and treat every credential that ever touched that box as potentially exposed.
- **A specific tenant's data is the concern (not app-wide)**: that tenant can be deactivated immediately (`Tenant#deactivate!`), and — since `Commerce7::PurgeDeactivatedTenantsJob` only purges after 30 days — hard-deleted sooner by running it manually or destroying the `Tenant` row directly if the situation warrants immediate erasure rather than waiting out the window.
- **Unreviewed/unexpected production deploy**: check the GitHub Actions run and the commit it deployed; if it's bad, revert on `main` and let the Deploy workflow redeploy the revert — don't hand-patch the running container.

## 5. Notification

- **Commerce7**: support@commerce7.com, within 4 hours of detection, per their App Security Policy. Include what happened, what's affected (which tenant(s), what data), containment steps already taken, and current status.
- **Affected tenant(s)**: if a specific winery's data was exposed, notify them directly once scope is confirmed — don't wait for full root-cause analysis to give an initial heads-up.
- **Internal**: even as a single-maintainer project, write down the timeline as you go (see §7) — reconstructing it later from memory is unreliable.

## 6. Eradication and recovery

1. Confirm the root cause before redeploying — a credential rotation without knowing *how* it leaked just delays a repeat.
2. Deploy the fix through the normal branch → PR → merge → CI/CD path (`.github/workflows/deploy.yml`), not a manual hotfix on the droplet — manual changes don't survive the next deploy and won't be reviewed.
3. Re-run the affected sync paths if data integrity is in question: `Commerce7::SyncJob.perform_later(tenant)` re-pulls that tenant's club membership data from Commerce7 as the source of truth.
4. Verify via `AuditEvent` and container logs that the incident has actually stopped, not just that the fix was deployed.

## 7. Post-incident review

Within a few days of resolution, write down: what happened, when it was detected vs. when it actually started, what data/tenants were affected, root cause, what contained it, and what changes (code, process, or this document) prevent a repeat. Update this plan if the incident revealed a gap in it.

## 8. Standing hygiene (reduces the chance of needing this document)

- Rotate the Commerce7 App Secret Key and the shared webhook Basic Auth credential at least every 90 days, per Commerce7's App Security Policy — there's no automated reminder for this yet; track it manually until there is.
- Keep `~/.ssh/authorized_keys` on the droplet limited to keys that are actually in current use.
- `AuditEvent` is retained 180 days (`AuditEvent::RETENTION_DAYS`) and pruned daily — pull anything relevant into a durable location before that window closes if it's ever needed for a longer-running investigation.
