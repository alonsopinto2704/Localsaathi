# Phase 039 Evidence - HTTP authorization regression pack

**Status:** Blocked

## Objective
A repeatable pack that exercises authorization over real HTTP (PostgREST `/rest/v1`, Storage `/storage/v1`) with real role tokens, so a regression in grants, schema exposure, RPC ownership checks, the public key allowlist or Storage policies fails a build.

## Blocker
- **The real run has NOT been executed.** There is no Supabase project and no Docker in this environment (same blocker as `phase-006.md`).
- **Missing dependency:** a disposable Supabase project (local stack via Docker + Supabase CLI per phase 006, or a throwaway cloud project) with migrations `0001`-`0019` applied.
- **Owner:** user (Docker Desktop / project creation), with the integration engineer.
- **Next action:** provision per phase 006, seed (below), export env, run `node backend/scripts/http-authz-pack.mjs`, paste the table here, flip status.

## Changed paths
- `backend/scripts/http-authz-pack.mjs` (new)
- `docs/backend-contract.md` (updated to the `0013`-`0019` contract)
- `tasks/evidence/phase-039.md` (this file)

## What runs where
| Concern | SQL level (PGlite, `verify-db.mjs` suites) | HTTP-only (this pack, needs a real stack) |
|---|---|---|
| Function bodies: `not_owner`, `validation_failed`, revision conflict, publish rules, rate-limit counters, `is_publicly_listed`, allowlist keys in `public_profile_json` | covered | re-checked end-to-end for the not_owner and key-allowlist cases |
| `GRANT`/`REVOKE` effect through the API roles (`anon` GET of a revoked table is a 401/403, not 0 rows) | partly (role switching in SQL) | **HTTP-only**: PostgREST role mapping and schema cache |
| Direct `PATCH` on a table by an owner is refused | partly | **HTTP-only** |
| Functions not exposed to `anon` over `/rpc/` | partly | **HTTP-only** |
| `private` schema not reachable | not testable | implicit (never listed); add a probe if config.toml changes |
| Storage bucket policies (private bucket read, cross-folder upload) | not testable (no Storage service) | **HTTP-only** |
| JWT handling / expired token / service-role refusal | not testable | pack refuses service-role tokens before any request |

## Probes (23 named checks; exit 1 if any fail)
anon denied on `provider_profiles`, `consent_records`, `verification_records`, `reports`, `engagement_events`, `app_admins` (an error is required, 0 rows fails); anon POST to `reports`/`engagement_events`/`city_requests` denied; anon rpc `provider_profile_json`/`public_profile_json`/`is_publicly_listed`/`admin_audit_events` denied; anon `search_providers` items contain only the 0016 allowlist keys, no snake_case/`moderationStatus`/`revision`/`isPubliclyListed`/`user_id`, phone only with consent and `+`, `mapLocation` at most 2 dp, and at least one listing (empty result fails as vacuous); anon `get_public_profile(HIDDEN)` is `null`; OTHER_JWT `update_profile_full`/`set_listing_status`/`delete_listing` on the owner profile -> error containing `not_owner`; OWNER_JWT direct PATCH denied; OWNER_JWT `get_owner_profile` has `revision`; anon GET `credential-evidence/<OWNER_USER_ID>/probe.txt` is 400/403/404; OTHER_JWT upload into the owner's `provider-photos` folder denied; ADMIN_JWT `admin_audit_events` is an array.

## How to run (after the blocker is cleared)
Seed: owner profile published + consented in `SEARCH_CITY_ID`/`SEARCH_LOCALITY_ID` (default `mh-mumbai` / `mh-mumbai-andheri-west`), a second user (OTHER), an admin in `app_admins`, a draft or suspended profile (HIDDEN). Never use the service-role key: the pack exits 2 if `SUPABASE_SERVICE_ROLE_KEY` is set or any token decodes to `service_role`.
```bash
export SUPABASE_URL=... SUPABASE_ANON_KEY=...
export OWNER_JWT=... OTHER_JWT=... ADMIN_JWT=...
export OWNER_PROFILE_ID=... HIDDEN_PROFILE_ID=... OWNER_USER_ID=...
node backend/scripts/http-authz-pack.mjs        # table + exit 1 on any FAIL
```
Warning: the `delete_listing` probe deletes the owner profile if the ownership check has regressed. Disposable project only.

## Self-test (executed here, no network)
`node backend/scripts/http-authz-pack.mjs --self-test` runs the key-allowlist check against a clean fixture (must PASS) and a fixture containing `phone_e164` and `moderationStatus` (must FAIL), proving a deliberate forbidden-field regression makes the pack fail. Also executed: with `SUPABASE_SERVICE_ROLE_KEY=x` set the pack printed the refusal and exited 2.

```
OK   search keys: clean response: pack reports PASS (expected PASS)
OK   search keys: injected phone_e164 + moderationStatus: pack reports FAIL (expected FAIL)
violations found in leaky fixture: [
  'items[0].provider.phone_e164 not in allowlist',
  'items[0].provider.moderationStatus not in allowlist',
  'forbidden key items[0].provider.phone_e164',
  'forbidden key items[0].provider.moderationStatus'
]
SELF-TEST PASSED: a forbidden-field regression makes the pack fail
exit=0
```

## Not verified
Every HTTP probe against a real stack. Exact status codes for revoked grants (expected 401/403, Postgres 42501) are assumed from PostgREST behaviour; the pack accepts any 4xx, so tighten after the first real run.
