# Phase 050 Evidence - Refresh and revocation

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Expired-token refresh without storms, revocation handling, offline recovery, bounded retries, no fallback to guest or mock for protected operations, drafts preserved.

## Changed paths
- lib/data/supabase/session_refresher.dart
- lib/data/supabase/supabase_provider_auth_repository.dart (`_protected`, `setRevocationListener`)
- lib/domain/repositories/auth_repository.dart (`SessionRevocationNotifier`)
- lib/app/controllers/session_controller.dart (`handleSessionLost` keeps the draft, sets `sessionLost`)
- test/auth_live_repository_test.dart (group names carry the phase number)
- test/session_storage_and_revocation_test.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Concurrent requests avoid refresh storms | 050: 8 concurrent protected calls with an expired token -> `refreshCalls == 1` | Pass |
| Revoked sessions cannot write | 050: revoked refresh -> `notAuthenticated`, `register_profile` never called, listener fired once | Pass |
| No guest/mock fallback | protected calls throw `RepositoryException(notAuthenticated)`; the controller moves to `signedOut` with `sessionLost = true` | Pass |
| Bounded retries / offline recovery | 050: offline -> exactly 3 attempts, 2 backoff sleeps, then `unavailable`; session kept; works after reconnect | Pass |
| Logout during refresh | 050: sign-out while refresh in flight -> result discarded, session stays null | Pass |
| Draft preserved on forced re-sign-in | revocation test: draft still loadable after `handleSessionLost`; `signOut` clears it | Pass |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 050 group: 4 tests pass
- `flutter test --no-pub test/session_storage_and_revocation_test.dart` -> `+6`

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
- Background resume is covered by "token expired -> refresh before the next protected call"; no lifecycle observer was added, and `supabase_flutter`'s own auto-refresh timer also runs. Two refreshers (SDK + ours) cannot both succeed with a rotated token: ours calls the SDK's `refreshSession`, which the SDK serialises. Confirm on a device that refresh-token rotation (`enable_refresh_token_rotation = true`, reuse interval 10 s) never logs a user out on resume.
- Refresh token reuse detection in GoTrue revokes the session family; a double refresh from two code paths could trigger it. Not observable without a real project.

## Rollback / safe stop
Stop protected writes pending a new session (this is the implemented behaviour).

## Next action
Device/staging test of resume-after-hours and rotation.
