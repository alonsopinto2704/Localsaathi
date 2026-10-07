# Phase 004 Evidence - Database test runner repair

**Status:** In review
**Objective:** Make `node backend/scripts/verify-db.mjs` run every intended pgTAP suite to its full plan; any error, missing/short plan or failed assertion exits nonzero. No production rule weakened.

## Prerequisites checked
- Phase 001 evidence not re-verified here (runner is independent of it).
- Node v24.19.0; `@electric-sql/pglite` 0.5.8 + `pglite-pgtap` already in `backend/node_modules`. No Docker needed.

## Changed paths
- `backend/scripts/verify-db.mjs` - files not ending `.test.sql` (i.e. `0000_helpers.sql`) are loaded once as setup, not run as TAP suites; an error in setup or zero suites fails the run.
- `backend/supabase/tests/database/0000_helpers.sql` - added `tests.moderate_as_admin()` and `tests.share_fixture()`.
- `backend/supabase/tests/database/0002_ownership_and_publication.test.sql`, `0003_credentials_and_promotions.test.sql`, `0004_city_activation_and_deletion.test.sql` - fixture fixes (below).
- `backend/supabase/tests/database/README.md` - run command, setup-vs-suite convention.
- Migrations untouched.

## Commands + actual results
**Baseline (original runner, before any change)** - `cd backend && node scripts/verify-db.mjs`, exit 1:
```
Migrations applied: 12/12
Seed applied: seed.sql
FAIL 0000_helpers.sql           no plan found in TAP output
ok   0001_phone_uniqueness.test.sql (3 tests)
FAIL 0002_ownership_and_publication.test.sql
      error: not_owner: only an administrator may change moderation status
      CONTEXT: PL/pgSQL function enforce_profile_mutation_rules() line 5 at RAISE
FAIL 0003_credentials_and_promotions.test.sql   error: permission denied for table fx
FAIL 0004_city_activation_and_deletion.test.sql
      error: listing_not_publishable: phone display consent is required to publish
ok   0005_private_fields.test.sql (4 tests)
Tests: 2/6 files passed, 7/7 assertions passed. FAIL
```
**After fix**, exit 0:
```
Migrations applied: 12/12
Seed applied: seed.sql
Setup loaded: 0000_helpers.sql
ok 0001 (3)   ok 0002 (3)   ok 0003 (3)   ok 0004 (4)   ok 0005 (4)
Tests: 5/5 files passed, 17/17 assertions passed. PASS
```
**Exit-code proof** (0005 temporarily mutated, then restored byte-identical, verified with `cmp`):
- short plan (`plan(4)` -> `plan(5)`): `FAIL 0005 ... planned 5 tests but ran 4`, exit=1
- added `select ok(false, 'deliberately broken assertion')`: `not ok 5`, `17/18 assertions passed. FAIL`, exit=1
- restored: PASS, exit=0
- Missing plan / SQL error already produced exit 1 in the baseline run: the original failure logic was sound; the failures were fixture and classification bugs.

## Findings (root cause per failure)
1. Helpers were run as a TAP suite -> "no plan". Fixed by the `.test.sql` suffix convention.
2. 0002 moderation: test did a plain `update ... set moderation_status='suspended'` as superuser with no JWT; the real trigger correctly rejects non-admins. Fix: `tests.moderate_as_admin` inserts a throwaway `app_admins` row and applies the change under that admin's claims, so the trigger and `is_admin()` are exercised, not disabled.
3. 0003 `permission denied for table fx`: temp table owned by the session user was queried after `set role authenticated`. Fix: `tests.share_fixture('fx')` grants it to anon/authenticated (test-only, session-scoped).
4. 0004 consent: `register_profile` was called without `phoneDisplayConsented`, so the later publish correctly failed the consent gate. Fix: pass `phoneDisplayConsented: true` (valid consent path); publication still goes through the consent/category/service-area trigger.
- No migration bug found. All three failing behaviors were correct production behavior.

## Security/privacy effect
None in production code. Suites now exercise the admin-only moderation gate legitimately rather than skipping it. Synthetic phones/ids only.

## Residual risks
- PGlite session user is a superuser (noted in `scripts/supabase-stub.sql`); security-definer/owner differences are only checkable on a real stack (Phase 006).
- `not ok ... # TODO` is tolerated by the runner (standard TAP); none exist today.
- Only 17 assertions; storage-bucket policies and owner-update success are not covered by any suite (see Phase 006).

## Rollback
Restore previous runner/tests from the tarball backup; no data or migration effects.

## Next integration action
Reviewer confirms; run `npm --prefix backend test` in CI. Consider a `0006` suite for storage policies and an owner-update success case.
