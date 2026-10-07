# Phase 027 — Publication invariants

**Status:** In review. Verified locally (PGlite). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Publishing must require a verified identity, current consent, an enabled market and category, the required content, and moderation acceptance. Edits to an already-published listing must not bypass these checks.

## Changed paths
Migration `…15`: `enforce_profile_mutation_rules` is rewritten as SECURITY DEFINER (it reads `auth.users`), and `public.is_publicly_listed` is added.

## Implementation
- **On publish (INSERT, or a transition to published), all of these are required:**
  - phone display consent;
  - a display name;
  - a confirmed phone identity in `auth.users` (new);
  - an active city (new);
  - at least one launch-approved category (new);
  - a service area;
  - not suspended.
- **While published:** an edit must keep a display name. Withdrawing phone consent auto-pauses the listing (phase 032).
- **Defense in depth:** `is_publicly_listed()` re-evaluates the whole rule on every public read. So an invalid listing cannot stay publicly eligible, whatever path changed the data: an un-approved category, a deactivated city, or a suspension.

## Bug found by the test suite and fixed
- **Symptom:** the first version applied the consent auto-pause *before* the publish gate. Publishing a never-consented draft was therefore silently rewritten to "paused" instead of failing.
- **Failing output (test worker):** `not ok 1 - publishing without phone display consent is refused … no exception thrown`.
- **Fix:** the auto-pause now applies only when `old.status = 'published'`. The assertion is restored in `0009`, whose plan went from 11 to 12.

## Verification
- `0009` (12 assertions).
- `0010`: market and category deactivation hide the listing.
- `0002` and `0004`.
- Suite: `Tests: 14/14 files passed, 149/149 assertions passed. PASS`.

## Rollback
Pause invalid listings pending owner correction (plan). The predicate already removes them from discovery.
