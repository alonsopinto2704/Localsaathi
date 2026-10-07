# Phase 059 Evidence - Authentication stress scenarios

**Status:** Done locally (uploads and hosted provider outages not exercised) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Exercise concurrent sign-ins, logout during refresh, account switching and outages; confirm retries and background work stop when account authority changes.

## Changed paths
- lib/app/controllers/session_controller.dart (identity epoch: results of in-flight verify/register/update/publish/status/availability calls are discarded after sign-out, deletion or revocation)
- test/auth_live_repository_test.dart (group names carry the phase number)
- test/session_storage_and_revocation_test.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Concurrent sign-ins never cross account boundaries | 059: two codes requested while signed out, A verified, then B's challenge refuses (bound to the signed-out session); one identity exists | Pass |
| Logout during refresh | 050 test (shared) | Pass |
| Logout during verification | 059: sign-out mid-verify -> controller stays signed out, no session | Pass |
| Account switching during writes | 059: sign-out mid-registration -> created profile is not attached to the controller; draft cleared by sign-out | Pass |
| Number change during edits | 052 tests: change conflicts leave the original number and profile; a successful change is picked up by the next `restore()`; an in-flight edit is not specially cancelled (the profile row keeps its owner) | Partially covered |
| Provider outages | 045/050/052/057: offline verify, refresh, change and delete never produce success and keep the account | Pass |
| Aggregate failure types without secrets | server counters `otp_stats`; client tests assert only counts | Pass |
| No duplicate live identities | 059 + 0018/0019/0022 uniqueness paths | Pass |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 059 group: 4 tests pass

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
- Account switching during PHOTO UPLOADS is not covered: uploads still use the mock repository until Workstream 4/phase 061+. The epoch guard is applied to profile writes; upload paths must adopt it when they go live.
- Provider outages were simulated by the fake gateway only, not by chaos testing a real stack.

## Rollback / safe stop
Disable the failing protected path, preserving guest search (guest browsing never touches the auth repository).

## Next action
Add the epoch guard to upload/photo calls in Workstream 4; chaos-test on staging.
