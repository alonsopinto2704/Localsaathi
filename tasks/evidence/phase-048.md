# Phase 048 Evidence - Enumeration resistance

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Before a code is verified nothing the app or API returns depends on whether a number owns a listing, is suspended or deleted; account state appears only after proof of control.

## Changed paths
- lib/data/supabase/supabase_provider_auth_repository.dart (no profile reads in `requestOtp`; decoy challenge for a taken number on phone change)
- test/auth_live_repository_test.dart (group names carry the phase number)
- backend/supabase/tests/database/0018_otp_guard.test.sql (gate answer identical for registered and unregistered numbers)
- backend/supabase/migrations/20261007000024_otp_guard.sql (`my_account` returns E.164 with `+`)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Pre-verification behaviour does not disclose listing ownership | 048: new vs existing number -> identical result shape, identical `simulatedCode`, identical validity window; `rpcCalls` is empty after requesting a code | Pass |
| Ownership revealed only after verification | 048: `existingProfileId` is set only from `verifyOtp` | Pass |
| Suspended / existing not visible before proof | 048: suspended account -> request succeeds with no RPC; `isSuspended` readable only after verify | Pass |
| Timing / server gate | 0018: `otp_send_gate` returns the identical JSON for a registered and an unregistered number (it never reads accounts) | Pass |
| Authenticated phone-change probing | 048: changing to a number owned by someone else returns a normal-looking challenge; any code then fails as "invalid"; no transfer, owner untouched | Pass |
| Support lookup endpoints | no lookup endpoint exists; `my_account`/`my_profile` are bound to `auth.uid()`; the HTTP pack asserts anon cannot call owner functions | Pass (SQL); HTTP unexecuted |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 048 group: 4 tests pass

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
- GoTrue itself answers `signInWithOtp` identically for new and existing users when signups are enabled (`enable_signup = true`). Response TIMING of GoTrue/the SMS provider for existing vs new numbers was not measured (no stack). Deleted numbers behave like new ones (the auth row is gone).
- The decoy on phone change means a user who mistypes a number belonging to another account gets no SMS and a "wrong code" later; the UI copy should say "if the number can be used, a code is sent". Acceptable trade-off for enumeration resistance.
- Finding fixed on the way: `my_account()` returned GoTrue's `+`-less number although the contract says E.164; fixed in migration 0024 and tolerated by the client.

## Rollback / safe stop
Return generic verification responses (already the behaviour) while investigating.

## Next action
Measure response-time spread on a real project for existing vs new numbers.
