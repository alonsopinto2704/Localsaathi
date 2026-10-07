# Phase 054 Evidence - Administrator MFA and roles

**Status:** Done locally (TOTP enrolment UX and hosted MFA behaviour unexecuted) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Privileged access requires MFA and separate support/moderation/credential-review/infrastructure roles, no shared identities, no client-controlled roles.

## Changed paths
- backend/supabase/migrations/20261007000027_admin_roles_mfa.sql (`private.admin_roles`, new `is_admin()`, `has_admin_role`, `private.require_admin_role`, role-scoped `set_feature_flag`, `record_credential_review`, `set_city_launch_status`, `set_category_launch_approval`, `enforce_profile_mutation_rules`)
- backend/supabase/tests/database/0021_admin_roles_mfa.test.sql
- backend/supabase/tests/database/0000_helpers.sql (`create_admin` grants roles, `authenticate_as_admin`, `moderate_as_admin` uses an MFA session)
- backend/supabase/tests/database/0010_market_activation.test.sql, 0013_audit_and_retention.test.sql, 0015_audit_followups.test.sql (admin sessions now aal2)
- backend/supabase/config.toml (`[auth.mfa.totp]`)
- docs/identity-operations.md (section 2)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Metadata edits cannot confer privilege | 0021: a user with `raw_app_meta_data`/`raw_user_meta_data` saying admin plus JWT claims `app_metadata.role=admin` is not an administrator; an ordinary account cannot insert into `app_admins` or `private.admin_roles` (42501) | Pass |
| Admin routes require adequate assurance | 0021: aal1 session of a real admin -> `reauth_required` and `is_admin()` false; legacy `app_admins` row without roles -> not admin; anon -> false | Pass |
| Stale privileged sessions | 0021: aal2 but TOTP proof 30 min old -> sensitive RPC refused (`reauth_required`) while `is_admin()` stays true for non-sensitive reads | Pass |
| Separate roles | 0021: moderation cannot set flags or review credentials; support cannot change moderation status; moderation can; revoked role unusable immediately | Pass |
| No shared identities | roles attach to individual `auth.users` ids; grants/revocations audited (`admin_role_granted/revoked`, 4 + 1 in the test) | Pass |
| Existing suites still pass | 0010, 0013, 0015 updated to MFA admin sessions; all 23 files green | Pass |

## Commands run for this phase (actual results)
- `npm --prefix backend run test:db` -> `ok 0021_admin_roles_mfa.test.sql (17 tests)`; full `Tests: 23/23 files passed, 296/296 assertions passed. PASS`

## Verification run (2026-10-07, after the last change of phases 041-060)
| Command | Actual result |
|---|---|
| `npm --prefix backend test` | `Migrations applied: 29/29`, `Tests: 23/23 files passed, 296/296 assertions passed. PASS`, then Node: `tests 27, pass 27, fail 0` |
| `C:\Users\alonso\flutter\bin\flutter.bat test --no-pub -r failures-only` | `+360: All tests passed!` (0 skipped; the tree also contains concurrent phase-101 test work; the five identity files added by phases 041-060 contribute +110) |
| `flutter analyze` | 73 issues, all `info`; 0 errors, 0 warnings; none in files added by these phases |
| `node backend/scripts/rehearse-migrations.mjs` | `Rehearsal: 26/26 checks passed (2000 synthetic providers).` (upgrade 0001-0012 -> 0029) |
| `node backend/scripts/http-authz-pack.mjs --self-test` | `SELF-TEST PASSED` (the live run is still blocked: phases 006/039) |
| `node backend/scripts/check-identity-config.mjs` | `Identity config: PASS` |

## Assumptions and remaining uncertainty
- BREAKING CHANGE (intended): existing `app_admins` rows lose all admin power until they are given a role AND sign in with MFA. There are no admin rows in seed.sql.
- GoTrue stamps `aal` and `amr` (with timestamps) in the JWT after MFA verification; the tests inject those claims. The claim names/shape (`aal2`, `amr[].method/timestamp`) follow Supabase documentation as recalled and must be confirmed on a hosted project.
- Moderation-status changes (the profile trigger) and reports/promotions RLS keep using `is_admin()` (any role + MFA); only the four listed RPCs and the moderation fields are role-scoped. Reports/promotions RLS role-scoping is left for the admin-console workstream.
- TOTP enrolment UI does not exist; enrol via the Auth API/dashboard.

## Rollback / safe stop
Revoke privileged sessions and disable affected roles: `delete from private.admin_roles ...` takes effect on the next request.

## Next action
Confirm claim shape on a hosted project; build the enrolment/admin console flow.
