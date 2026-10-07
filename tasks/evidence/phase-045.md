# Phase 045 Evidence - Verification and replay

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Verify codes only through the server verifier, map failures without revealing registration state, reject replay, and never infer success locally.

## Changed paths
- lib/data/supabase/supabase_provider_auth_repository.dart (`verifyOtp`)
- lib/data/supabase/supabase_auth_gateway.dart (GoTrue error mapping)
- test/auth_live_repository_test.dart (group names carry the phase number)
- test/support/fake_auth_gateway.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Consumed codes fail on replay | 045: burned challenge and burned server code both fail; a fresh challenge cannot reuse the old code | Pass |
| Wrong attempts create no session | 045: 4 x invalid then `attemptsExceeded` on the 5th; correct code afterwards fails on the discarded challenge; `currentSession` stays null | Pass |
| No local success on connectivity failure | 045: offline during verify -> `unknown`, no session, challenge kept; retry after reconnect succeeds | Pass |
| Wrong vs expired do not reveal registration | GoTrue reports both as `otp_expired`; mapped to `invalid` (local expiry is the only `expired`); identical for registered and unregistered numbers | Pass by design |
| Input hygiene | 045: Devanagari digits with spaces accepted; wrong length rejected locally with zero server calls | Pass |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 045 group: 5 tests pass

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
- The server-side attempt limit is GoTrue's rate limit (`token_verifications` in config.toml), not a per-code counter; the client adds a 5-attempt budget per challenge. Confirm GoTrue behaviour on repeated wrong codes against a real project.
- A verified session whose phone differs from the challenge's number is refused and signed out (defence against a mixed-up identity).

## Rollback / safe stop
Invalidate the local challenge and offer controlled resend (the UI already returns to phone entry on `attemptsExceeded`).

## Next action
Real-project check of `verifyOTP` error codes (phase 060 staging list).
