# Phase 037 — Forward migration rehearsal

**Status:** In review → accepted by Opus reviewer (author), 2026-10-06 · **Human sign-off:** pending

## Objective
Apply the new migrations (20261006000013–20) to a database shaped like the previous release, with volume, and prove: it upgrades, old client calls keep working, an interrupted upgrade is recoverable.

## Changed paths
- `backend/scripts/rehearse-migrations.mjs` (new): rehearsal harness.
- `backend/scripts/db.mjs` (new): shared PGlite boot used by verify-db, inventory, rehearsal, benchmarks.
- `backend/supabase/migrations/20261006000015_listing_integrity.sql`: **phone backfill added before the E.164 constraint** (found by this rehearsal).

## Method
1. Prior release = migrations `20260101000001–12` + `seed.sql` + N synthetic providers written the old way: GoTrue-format phones without `+` (exactly what old `register_profile`/auth sync stored), published, consented, WhatsApp on.
2. Apply each new migration in order, timing each file.
3. Call the old RPC shapes as `anon`; try an old direct-table write.
4. Fresh prior-release DB: apply new migrations up to `…17`, apply `…17` with an injected `select 1/0;` at the end, confirm nothing from that file remains, then re-run the rest.

## Commands and results
`node backend/scripts/rehearse-migrations.mjs --providers 2000`
```
ok   prior release holds GoTrue-format phones (the backfill case) -- 2000 rows
ok   apply 20261006000013_privilege_hardening.sql -- 21 ms
ok   apply 20261006000014_audit_log.sql -- 14 ms
ok   apply 20261006000015_listing_integrity.sql -- 361 ms
ok   apply 20261006000016_public_projection.sql -- 11 ms
ok   apply 20261006000017_owner_writes.sql -- 12 ms
ok   apply 20261006000018_guest_writes.sql -- 11 ms
ok   apply 20261006000019_retention.sql -- 13 ms
ok   every phone is E.164 after upgrade
ok   backfill did not bump revisions or re-run publication rules
ok   old search_providers(city, locality) call shape still works -- 20 items (old schema returned 20; limit default 20)
ok   results keep the client keys (id, displayName, phoneE164, workingHours...)
ok   old get_public_profile(id) call shape still works
ok   old direct-table report insert is now refused (documented breaking change) -- 42501
ok   injected failure in 20261006000017_owner_writes.sql rolls the whole file back
ok   re-running the remaining migrations after the failure succeeds
Rehearsal: 16/16 checks passed (2000 synthetic providers).
```

**Original failing reproduction (kept, per plan rule):** with the backfill temporarily removed from `…15` (file restored afterwards, verified with `cmp`):
```
FAIL apply 20261006000015_listing_integrity.sql -- check constraint "provider_phone_is_e164" of relation "provider_profiles" is violated by some row
```
So the first version of migration 15 would have **failed on any real database** that had registrations. The backfill normalises `provider_profiles.phone_e164` and `consent_records.phone_e164` with user triggers disabled (pure format fix: no revision bump, no publication re-check).

## Compatibility decisions
- **Kept (additive):** every RPC name and argument list from 0008/0012; public JSON keeps all keys the Dart model reads. The owner JSON adds `revision` and `isPubliclyListed`; the public JSON adds `storagePath` on photos and `state` on promotions.
- **Breaking, deliberately:** direct table writes (publish/pause/availability/delete/photos/consent/report/engagement/city request) and anon raw-table reads. Safe now because no shipped client uses them: `lib/data/supabase/` does not exist and the app runs on mocks (phase 001/007). The replacement RPCs are in `docs/backend-contract.md` (phase 039 worker update).
- Expand/contract: no columns were dropped or renamed. `reports.provider_id` became nullable (expand only).

## Locking (honest limits)
PGlite is single-connection, so lock contention cannot be observed here. By inspection: `…15` takes ACCESS EXCLUSIVE on `provider_profiles` for `ADD COLUMN revision … DEFAULT 1` (metadata-only on PG11+) and `ADD CONSTRAINT … CHECK` (full scan). That was 361 ms for 2,000 rows in PGlite. At launch scale (hundreds to a few thousand rows) this is sub-second; above ~100k rows, split it into `ADD CONSTRAINT … NOT VALID` + `VALIDATE CONSTRAINT` in a separate migration. Each file is one transaction under the Supabase CLI, so an interrupted run leaves the previous schema.

## Not verified
Hosted Supabase `supabase db push` against a real prior-version project (phase 006 is blocked on Docker/accounts), concurrent traffic during migration, and a real mobile build against the new contract (no live client exists yet).

## Rollback
Forward repair only (per plan). The rehearsal shows each new file applies atomically. To back out the API change for a client, keep these migrations and add a compatibility RPC rather than re-granting table writes.

## Re-run after code-review fixes and the phase 038 index (2026-10-07)
`node backend/scripts/rehearse-migrations.mjs --providers 2000` → `Rehearsal: 17/17 checks passed` (2026-10-06; after migrations 0021–0022 the same command reports **19/19**, re-run 2026-10-07). The new check is `apply 20261006000020_measured_indexes.sql`.

The harness first picked its injected-failure "victim" by position (third from last). Adding migration 20 shifted that pick to `…18`, while the assertion still looked for `set_listing_status`, which `…17` defines. The victim is now chosen by name (`owner_writes`).
