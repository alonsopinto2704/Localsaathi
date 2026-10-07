# Phase 025 — Provider row and column controls

**Status:** In review. Verified locally (PGlite); HTTP verification Blocked (phases 006/039). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
No raw-table path may bypass the public projection. Phone, ownership, moderation and internal fields must be protected against direct API writes.

## Changed paths
- Migration `…13`: revokes all table privileges, then grants per table.
- Migration `…17`:
  - owner RPCs that replace direct writes;
  - drops the 0009 public-row SELECT policy and the now-unreachable write policies.

## Implementation
- **anon** has no grant on any provider table.
  - Before, anon could SELECT every column of every published row. That included the phone number regardless of consent, `user_id`, exact `map_lat/lng` and `suspension_reason` (executed probe by the independent audit).
- **authenticated** has SELECT only, and the remaining policies match the caller's own rows (or admin).
  - **Found and fixed during this phase:** after `…13`, any signed-in user could still read every published row raw through the 0009 policy "published and active listings are public". `…17` drops it.
- **No direct writes.** There are no INSERT/UPDATE/DELETE grants on `provider_profiles` or any child table.
  - The audit's "squatter" attack (a signed-in user inserting a published row carrying someone else's phone) now fails with 42501.
- **`credential_records`:** the column-level INSERT grant excludes `status` and `reviewed_*`.
- **Writes go through RPCs:** `set_listing_status`, `set_availability`, `delete_listing`, `add_provider_photo` (path must be `<own uid>/<file>`, no client URL stored), `delete_provider_photo`, `record_consent`, `update_profile_full`, `register_profile`.
- **Trigger `enforce_profile_mutation_rules`:**
  - `id` and `user_id` are immutable, so ownership cannot be transferred;
  - moderation fields are admin-only;
  - the phone changes only through the auth sync trigger;
  - `created_at` and `published_at` are preserved.

## Verification
- Suites `0002`, `0003`, `0005` and `0008`:
  - direct INSERT/UPDATE/DELETE fails with 42501 for owners and others;
  - a provider counts exactly one profile row (their own);
  - a provider cannot select another provider's **published** row.
- **Mutation checks.** Each injection was appended to a migration, the suite was run, and the file was restored (verified with `cmp`). Every injection made the suite fail with exit 1:

| Injected regression | Assertions that failed |
|---|---|
| `grant select on public.provider_profiles to anon` | `0005` #3 |
| `grant update … to authenticated` + `using (true)` | `0002` #1 and `0008` #14 |
| `create policy leak … using (status = 'published')` | `0008` #10 and #11 |

  The first version of the `0008` read check targeted a draft row and **missed** the published-rows mutation. It was retargeted at a published row and now catches it.
- Suite: `Tests: 14/14 files passed, 149/149 assertions passed. PASS`.

## Breaking change
Clients must use the RPCs (`docs/backend-contract.md` is updated). No client uses Supabase yet: `lib/data/supabase/` does not exist, so nothing in the field breaks.
