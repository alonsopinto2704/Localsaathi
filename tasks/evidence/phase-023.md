# Phase 023 — Internal function isolation

**Status:** In review. Verified locally (PGlite); HTTP verification Blocked (phases 006/039). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
No helper is callable from the API unless it is allowlisted. Nested calls keep working because of function ownership, not broad grants.

## Changed paths
`backend/supabase/migrations/20261006000013_privilege_hardening.sql`

## Implementation
- **Revoke everything.** `revoke execute on all functions in schema public from public, anon, authenticated`, plus a **global** `alter default privileges revoke execute on functions from public`.
  - The global form is necessary: per-schema default privileges cannot remove Postgres's built-in PUBLIC EXECUTE.
  - Revoking only from anon would have left EXECUTE reachable via PUBLIC (the independent audit confirmed this).
- **Grant explicitly, per function:** discovery to anon + authenticated; owner and admin RPCs to authenticated. Each later migration grants its own new functions.
- **Move `pg_trgm`** out of `public` into `extensions`. That removes ~30 C functions from the API surface. Trigram indexes still work, and the search tests pass.
- **Leave helpers ungranted:** `provider_profile_json`, `assert_locality_in_city`, `public_profile_json`, `is_publicly_listed` and `private.*`. They run inside SECURITY DEFINER callers as the function owner. Trigger functions need no EXECUTE grant (Postgres does not check it when a trigger fires).
- **Test-only re-grants:** `verify-db.mjs` grants pgTAP's functions in `extensions`, and the `tests` schema, back to the API roles. Neither exists in production.

## Verification
- `0006_privileges`:
  - anon's EXECUTE set equals the 12-function allowlist exactly;
  - anon calling `provider_profile_json`, `is_publicly_listed` or `public_profile_json` gets 42501;
  - `pg_trgm` lives in `extensions`;
  - anon has no USAGE on `private`.
- **Mutation check:** appending `grant execute on function public.provider_profile_json(uuid) to anon` to a migration fails `0006` (`not ok 1 - anon can execute exactly the discovery allowlist…`, exit 1). The file was restored afterwards and verified with `cmp`.
- Suite: `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Rollback
Restore only a specifically justified grant (plan rule). Never re-run 0009's blanket grant.
