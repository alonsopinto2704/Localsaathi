# Identity operations runbook (phases 047-060)

Applies to migrations 0024-0029, the `send-sms-hook` and `delete-account` Edge
Functions and the Flutter live auth repository. Nothing here has been run
against a hosted Supabase project yet (no Docker or project available); every
statement about runtime behaviour is covered by the local PGlite/Node/Flutter
tests listed in `tasks/evidence/phase-0NN.md`.

## 1. Code spend control (phase 047)

| Layer | Control | Default | Owner |
|---|---|---|---|
| App | 60 s resend pacing, one in-flight request | courtesy only | mobile |
| Auth | `max_frequency = 60s` per number, `[auth.rate_limit] sms_sent` project ceiling, `token_verifications` | `config.toml` | backend |
| Hook gate (`public.otp_send_gate`) | only `+91` mobiles; 3 codes/number/hour, 8/number/day; 30/hour per 10,000-number block; 300/hour and 1,500/day globally | rows in `private.otp_limits` | backend/security |
| Circuit breaker | hitting a global ceiling stops all sending for `breaker_minutes` (60) and writes `otp_breaker_opened` to `private.audit_events` | same table | backend/security |

Tune during an attack without a deploy:

```sql
update private.otp_limits set value = 100 where key = 'global_hour';
select public.otp_breaker_reset();          -- service role / SQL editor, audited
select day, metric, n from private.otp_stats order by day desc, metric;  -- aggregate counters
```

**Alerting is not wired** (no hosted project). Required at deployment: an
alert on any new `otp_breaker_opened` audit row and on `denied_*` counters
rising sharply (owner: backend/security engineer). Until then the ceilings
bound the loss: worst case is the global daily ceiling times the per-message
price (see `docs/sms-provider-evaluation.md`). Schedule
`select public.purge_otp_send_log();` and `select public.purge_deletion_jobs();`
daily (pg_cron, deployment task).

Legitimate shared-network users: limits are per number and per number block,
not per IP, so an office or a mobile carrier NAT does not lock users out;
recovery is the retry-after returned by the gate once the window passes.

## 2. Roles and MFA for administrators (phase 054)

Administrators are ordinary accounts with a row in `public.app_admins` **and**
one or more roles in `private.admin_roles` (`support`, `moderation`,
`credential_review`, `infrastructure`), and they must hold an MFA (`aal2`)
session. Privilege never comes from user metadata or a profile column.

Bootstrap (SQL editor, service role):

```sql
insert into public.app_admins (user_id) values ('<user uuid>');
insert into private.admin_roles (user_id, role) values ('<user uuid>', 'support');
```

Then the person enrols a TOTP factor (Auth MFA enrolment) and signs in again.
Revoke by deleting the role row: effective immediately and audited. There is no
shared admin identity. Sensitive actions (feature flags, market activation,
credential review, recovery review/execution) also need a TOTP proof from the
last 15 minutes. Emergency: delete the role rows (or `app_admins` row) and
revoke the user's sessions in the dashboard.

## 3. Phone change and SIM-loss recovery (phases 052, 053)

* Changing the number: the app calls `request_sensitive_action('phone_change')`
  (needs an SMS/TOTP proof from the last 5 minutes), then Auth's `updateUser`
  (blocked by a database trigger without that grant), then verifies the code
  sent to the new number. The profile keeps its owner; display/WhatsApp
  consent is reset for the new number and a published listing is paused.
* Lost SIM: the person verifies a **new** number (empty account), calls
  `open_recovery_case(listing, statement)`. Support reviews in
  `admin_recovery_queue()`, records a decision with a written rationale
  (`admin_review_recovery_case`), the 7-day wait runs (the real owner can
  `dispute_recovery_case`, which freezes it), then support runs
  `admin_execute_recovery`. A frozen case is never executed: it must be
  rejected and, if the claimant is genuine, reopened after the owner is
  reached.
* Support must contact the listing's business through an independent channel
  (an address or landline from before the incident), never the new number
  alone. Public facts are not proof.

## 4. Reviewer access without a back door (phase 056)

* No build contains a universal OTP, magic number or admin bypass. The demo
  code (`123456`) exists only in a `LS_ENV=demo` build and is rejected by the
  live repository and by Auth.
* `backend/supabase/config.toml` carries no `[auth.sms.test_otp]` (a fixed code
  would be pushed to a hosted project by `supabase config push`); the local
  example is `backend/supabase/config.local-test-otp.toml.example`.
* Store reviewers (Play) use a **separate staging project** with the fake SMS
  sender (`SMS_MODE=fake`) and Supabase's documented test-number feature for
  *that project only*, configured in its dashboard, with a synthetic reviewer
  provider profile (placeholder data) and no access to real providers' data.
  Rotate or delete the test number after review. This needs a Supabase staging
  project and is therefore a deployment task; instructions for reviewers:
  install the staging build, sign in with the supplied test number and code,
  the listing wizard and dashboard are fully usable; no admin or other
  provider's private data is reachable.
* Guard: `node backend/scripts/check-identity-config.mjs` (also in
  `npm --prefix backend test`).

## 5. Account deletion (phase 057)

`delete-account` verifies the caller's JWT, consumes a recent-auth grant, keeps
one job per user (`private.deletion_jobs`), deletes storage, then the auth user
(cascading the listing), and answers with stable codes only. After success the
token is dead (401): the app treats a 401 on a retry of its own deletion as
"done". Job receipts hold user id + timestamps only and are purged after 30 days.

## 6. Staging verification checklist (phase 060, not yet done)

Needs a Supabase staging project, the deployed hook, an SMS vendor (or the fake
sender) and 2-3 isolated test numbers:

1. Apply migrations 0001-0029; deploy both functions; set secrets.
2. `LS_ENV=staging` build; sign in with an isolated number; record delivery
   latency; confirm `123456` is rejected.
3. Run `node backend/scripts/http-authz-pack.mjs` with staging keys (never a
   service-role key).
4. Hit the per-number limit with the test number; confirm 429 and recovery.
5. Enrol TOTP for a staging admin; confirm an aal1 session cannot call
   `set_feature_flag`.
6. Revoke the session in the dashboard; confirm protected writes fail and the
   draft survives.
