# Phase 052 Evidence - Verified phone change

**Status:** Done locally (real GoTrue phone-change flow unexecuted) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Change the registered number only after recent authentication and verification of the new number, via trusted synchronisation, audited, with no profile transfer through conflict.

## Changed paths
- backend/supabase/migrations/20261007000025_phone_change.sql
- backend/supabase/tests/database/0019_phone_change.test.sql
- lib/data/supabase/supabase_provider_auth_repository.dart (`requestPhoneNumberChange`, `confirmPhoneNumberChange`)
- backend/supabase/migrations/20261007000026_sensitive_actions.sql (the recent-auth gate on the request)
- test/auth_live_repository_test.dart (group names carry the phase number)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Interrupted change preserves ownership | 0019: unconfirmed request leaves phone and published status unchanged; Dart: wrong codes/outage leave the account on the original number | Pass |
| Conflicting change preserves ownership | 0019: number of another account -> 23505, both profiles untouched; stale profile holding the number -> 23505 and `auth.users` rolls back; Dart: number taken between send and verify -> `DuplicatePhoneNumberException`, owners unchanged | Pass |
| Recent authentication required | 0020 + Dart 052: stale grant -> `reauth_required`, no SMS sent | Pass |
| Canonical identity via trusted sync, audited | 0019: profile follows the verified number (same row, same owner); `phone_changed` audited once, no numbers in the audit row; phone verification record written | Pass |
| Notification / session behaviour defined | consent for display and WhatsApp resets, a published listing pauses (never silently re-listed), consent rows record the new number; sessions are not revoked on a self-service change (the user just proved control); an SMS notice to the OLD number is NOT sent (documented gap) | Pass / gap noted |
| Deferred audit items | E.164 CHECKs on `consent_records.phone_e164` and `reports.reporter_phone_e164` (NOT VALID: new writes only); consent rows for the new number | Pass (0019 constraint test) |

## Commands run for this phase (actual results)
- `npm --prefix backend run test:db` -> `ok 0019_phone_change.test.sql (16 tests)`
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 052 group: 5 tests pass

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
- ASSUMPTION (safest default): consent to display a number does not carry over to a new number. If product prefers carry-over, change `handle_auth_phone_change` and test 0019.
- The real GoTrue sequence (`updateUser(phone)` writing `phone_change`/`phone_change_sent_at`, then `verifyOTP` type `phone_change` writing `phone`) is modelled from memory of GoTrue's schema, not observed. The trigger and tests must be re-run against a real stack (phase 060).
- GoTrue answers `phone_exists` to an authenticated user probing a number; the client masks that as a normal send, but the HTTP status is visible to a hand-written API client. Residual, low severity (requires a valid recent session).
- No SMS/notification is sent to the old number after a change; adding one needs the SMS vendor.

## Rollback / safe stop
Keep the original number until full commit (inherent: GoTrue only moves `phone` on verification; the trigger is one atomic statement).

## Next action
Re-run against a real stack; decide on an old-number notification.
