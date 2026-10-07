# Phase 055 Evidence - Sensitive-action reauthentication

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Server-side recent-authentication for deletion, phone change, private evidence export and sensitive admin actions, with a defined assurance age, cancellation and a fresh grant instead of automatic execution.

## Changed paths
- backend/supabase/migrations/20261007000026_sensitive_actions.sql (`private.sensitive_grants`, `private.auth_age_seconds`, `request_sensitive_action`, `consume_sensitive_grant`, `guard_phone_change` trigger on `auth.users`)
- backend/supabase/migrations/20261007000027_admin_roles_mfa.sql (admin actions need a TOTP proof under 15 minutes)
- backend/supabase/tests/database/0020_sensitive_actions.test.sql
- lib/data/supabase/supabase_provider_auth_repository.dart (requests the grant before phone change / deletion; maps `reauth_required`)
- backend/supabase/functions/delete-account/ (consumes the grant)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| A valid but old session cannot perform a sensitive action | 0020: amr proof 15 min old, future-dated, or absent -> `reauth_required`; GoTrue-style phone-change update without a grant -> refused; Dart: stale -> `reauthRequired`, no SMS, no deletion call | Pass (15 + Dart tests) |
| Assurance age defined | 5 minutes for user actions (grant valid 10 minutes, single use); 15 minutes for administrators | Defined and tested |
| Cancellation | a grant that is never used simply expires; the app's cancel path performs no call; nothing changes in account data | Pass (by design) |
| Return to the reviewed action with fresh authorization, not auto-execute | the grant only authorises; the user still confirms the screen (the repository requests it at confirm time) | By design |
| Single use / cross-user | 0020: second code send needs a new confirmation; another user's grant does not apply; expired grant refused | Pass |
| Abuse bound | 0020: 10 grant requests/hour then `rate_limited` | Pass |

## Commands run for this phase (actual results)
- `npm --prefix backend run test:db` -> `ok 0020_sensitive_actions.test.sql (15 tests)`

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
- The `private.auth_age_seconds()` basis is the newest `otp`/`sms`/`totp`/`phone` entry in the JWT `amr` claim. This is the documented Supabase behaviour as recalled; it was exercised only with injected claims. Verify that a fresh phone-OTP sign-in produces an `amr` entry with a numeric `timestamp` on the hosted version.
- `export_private_evidence` has a grant type but no endpoint yet; it is ready for the evidence-export phase.
- The phone-change trigger only gates the REQUEST (each send); confirmation needs no second grant because possession of the new number is the proof.

## Rollback / safe stop
Cancel the pending action without changing account data (grants expire unused).

## Next action
Hosted check of the `amr` claim; use `request_sensitive_action` in the private-evidence export phase.
