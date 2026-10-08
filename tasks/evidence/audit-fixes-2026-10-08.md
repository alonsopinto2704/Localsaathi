# Audit fixes 2026-10-08 (backend only; findings from tasks/evidence/audit-001-060.md)

Migrations 0050-0053, pgTAP 0050-0053, Node tests. No lib/, test/ or plan edits.

## Verification commands

Before (start of this work, other agents' 0030-0033 present): `npm --prefix backend test` Migrations 34/34, Node 27/27 pass; `rehearse-migrations.mjs` 30/30; `check-identity-config.mjs` PASS; `db-inventory.mjs` no anon/authenticated CREATE on public.

After (44 migrations present, incl. other agents' 0034-0043 in flight):
- `node backend/scripts/verify-db.mjs`: 37/38 files, 554/554 assertions passed. The one failing file is `0036_gallery_atomic.test.sql` ("permission denied for function photos"), another agent's in-flight work; not touched by these changes. (Earlier runs also showed transient failures in 0031/0032/0041/0042/0043 that cleared as those agents finished.) Because verify-db exits non-zero, `npm --prefix backend test` stops before the Node suite; the Node suite run alone: `node --test "test/**/*.test.mjs"` tests 30, pass 30, fail 0 (was 27).
- `rehearse-migrations.mjs`: "Rehearsal: 41/41 checks passed (2000 synthetic providers)."
- `check-identity-config.mjs`: PASS (local/demo). `--production`: FAIL, exit 1 ("[auth.hook.send_sms] is not enabled", "uri is not https").
- `db-inventory.mjs`: anon: no, authenticated: no CREATE on schema public.
- Fail-without-fix: with migrations 0050-0053 removed, verify-db fails 0018, 0023, 0050, 0051, 0052, 0053; with `check-identity-config.mjs` reverted, the new Node test `production profile ...` fails.

## Existing tests edited (behaviour they asserted was the audited defect)
- `0018_otp_guard`: block length 8 -> 9.
- `0022_recovery_cases`: a second admin (`admin2`) executes; the approver no longer can.
- `0023_deletion_jobs`: "different key converges" -> conflict; attempts 3 -> 2; two assertions on the dropped `account_deletion_status` removed (plan 17 -> 15).

## 1. HIGH 054, bare is_admin(): FIXED
Files: `backend/supabase/migrations/20261008000050_admin_role_gating.sql`, `backend/supabase/tests/database/0050_admin_role_gating.test.sql` (18 assertions), docs/backend-contract.md.
`has_admin_role` is now executable by `authenticated` (needed so RLS can evaluate it).
Every `is_admin()` use in the live schema (found via pg_proc/pg_policies after all migrations) and the decision:

| Site | Decision |
|---|---|
| `set_listing_moderation` | moderation role (`require_admin_role('moderation', false)`) |
| `admin_audit_events` | infrastructure role |
| RLS reports select/update | moderation |
| RLS engagement_events select | infrastructure |
| RLS promotions "for all" | infrastructure (no audited RPC exists for promotions; direct write kept, role-gated) |
| RLS promotion_interest admin branch | infrastructure |
| RLS app_admins select | infrastructure |
| RLS city_requests select (admin branch) | support |
| RLS "only admins write reference data" x7 (countries, state_regions, cities, localities, service_groups, service_categories, subscription_plans) | dropped; writes only via `set_city_launch_status` / `set_category_launch_approval` (infrastructure, audited). API roles had no write grant on these tables anyway; now no policy either |
| `set_city_launch_status`, `set_category_launch_approval`, `set_feature_flag`, `record_credential_review`, `enforce_profile_mutation_rules` | already role-gated in 0027 |
| `get_owner_profile`, `engagement_summary_for` (owner OR admin read) | kept: read-only, any MFA admin with a role |
| RLS owner-or-admin SELECT policies on provider_profiles, provider_* child tables, consent_records, verification_records | kept: read-only, any MFA admin with a role (support must see listings). Writes on those tables are not granted to `authenticated` |
| `private.require_flag` (admin bypasses a disabled flag) | kept: not an authorisation to write |
| `credential_records` policies, `storage.objects` "owner reads own credential evidence", `force_pending_credential_status`, `check_credential_claim` | left to the concurrent credential workflow (0040 rewrites these); `credential_records` grants exclude status, so no admin-only write path is open |
| `is_admin()`/`has_admin_role()` definitions, 0013 grants | unchanged |

Tests: support-only cannot suspend, read audit, read reports/engagement, create a promotion, list admins; moderation can suspend/resolve reports but not read audit; infrastructure can read audit/manage promotions but not resolve reports; no "only admins write reference data" policy remains and an all-role admin cannot write cities or flip a category even with a temporary table grant.

## 2. MED 053, recovery: FIXED
Files: `20261008000051_recovery_hardening.sql`, test `0051_recovery_hardening.test.sql` (9), docs.
- `admin_execute_recovery` refuses when `reviewed_by = auth.uid()` (`not_owner`); audit row now records the reviewer.
- `open_recovery_case`: per-listing cap removed; per claimant 3/day (existing) and 2 per listing per 30 days; the fifth case on a listing writes one `recovery_listing_flood` audit alert, never blocks. Test: three throwaway accounts file six cases, a genuine claimant still opens one.

## 3. MED 057, deletion resume: FIXED
Files: `20261008000052_deletion_resume_guard.sql`, `functions/delete-account/{logic,index}.ts`, tests `0052_deletion_resume_guard.test.sql` (13) and `test/delete-account.test.mjs` (+1), docs.
- Resume needs the same idempotency key (else `conflict` -> HTTP 409 `deletion_in_progress`); a job idle over 10 minutes needs a fresh `delete_account` grant (else `reauth_required` -> 403); new `cancel_account_deletion()` for the signed-in owner (audited, authenticated only).
- `account_deletion_status` dropped (smaller than wiring: after success the JWT's user is gone, so the Edge Function answers 401 before any lookup could run).

## 4. MED 047, OTP quota/alert/block: FIXED (with one deliberate limit)
Files: `20261008000053_otp_quota_alerts.sql`, `functions/send-sms-hook/{logic,index}.ts`, tests `0053_otp_quota_alerts.test.sql` (9), `test/send-sms-hook.test.mjs` (+1), docs/identity-operations.md.
- `otp_record_delivery(outcome, now, phone)`: a `rejected` send deletes that number's latest gate row (quota refunded). `timeout` is NOT refunded: the SMS may have been delivered and billed. Unbounded refund of rejections is bounded by GoTrue's 60 s per-number spacing and sms_sent=60/h (`ponytail:` comment in SQL).
- Breaker alert: the audit event `otp_breaker_opened` already existed and is tested; the opening call now returns `breakerOpened: true` and the hook logs `ALERT otp_breaker_opened` (no number). Delivery of alerts to a pager is still a deployment task (docs say so).
- Block: code takes 9 characters (+91 and six digits = 10,000 numbers) to match docs; note column updated; log rows with the old 8-char block age out within 48 h.

## 5. MED 047/060, production config check: FIXED
Files: `backend/scripts/check-identity-config.mjs` (`--production` or `LS_ENV=production`), `backend/test/identity-config.test.mjs` (+1 test).
Production fails unless `[auth.hook.send_sms]` is enabled, `secrets = "env(...)"` and uri is https. Default (local/demo) still passes.

## 6. LOW 053, JWT lifetime runbook: FIXED
`docs/identity-operations.md` section 3: access JWTs outlive recovery up to `jwt_expiry` (3600 s).

## Not done / caveats
- Edge Function changes (delete-account 409 mapping, hook phone/alert) run only in Node fakes, not Deno/live.
- Credential-related is_admin() sites deferred to the 0040 workstream (see table).
