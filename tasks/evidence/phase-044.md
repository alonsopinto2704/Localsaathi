# Phase 044 Evidence - OTP challenge mapping

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Bounded challenge-to-phone bookkeeping that cannot verify the wrong number, is cleared on logout/account change, restarts safely, and never exposes a simulated code in live mode.

## Changed paths
- lib/data/supabase/otp_challenge_book.dart
- lib/data/supabase/supabase_provider_auth_repository.dart
- lib/app/controllers/session_controller.dart (`developmentCodeHint` is null for live challenges)
- test/auth_live_repository_test.dart (group names carry the phase number)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Expired challenges cannot verify | 044: expired (11 min) -> `OtpFailure.expired`, no session | Pass |
| Cross-session challenges cannot verify | 044: challenge issued signed-out, another user signs in, verify -> `unknown`, existing session untouched | Pass |
| Bounded | 044: 4 issues -> 3 live, oldest evicted and unusable | Pass |
| Code for number B cannot open number A | 044: B's valid code against A's challenge is a wrong code, no session | Pass |
| Cleared on logout | 044: sign-out then verify with the old id -> `unknown` | Pass |
| Restart safely | the book is never persisted; after process death the user requests a new code, rate-limited by the server (046/047) | By design; covered by 046 restart test |
| Live mode never exposes simulatedCode | `OtpChallenge.simulatedCode` is always empty; `SessionController.developmentCodeHint` returns null for empty codes (051 test) | Pass |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 044 group: 4 tests pass (file total `+41`)

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
- Challenge ids are 16 random bytes from `Random.secure()`; they are not secrets worth hiding beyond the UI but are unguessable.
- A challenge is bound to the user id signed in at issue time; a legitimate flow "request code while signed out, verify while signed out" has `null` on both sides and passes.
- Local TTL (10 min) mirrors `[auth.sms] otp_expiry = 600` in config.toml; the server value is the authority.

## Rollback / safe stop
Switch back to `LS_ENV=demo`; the mock keeps its own `pendingChallenges`.

## Next action
None; continues in 045.
