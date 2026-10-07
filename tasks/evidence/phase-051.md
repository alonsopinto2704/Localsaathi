# Phase 051 Evidence - Owner-state restoration

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Restore the session from server-verified ownership and route new, published, paused, suspended and deleted accounts correctly without trusting cached ids.

## Changed paths
- lib/app/controllers/session_controller.dart (`restore`, `_statusFor`, `SessionStatus.suspended`, `isSuspended`)
- lib/data/supabase/supabase_provider_auth_repository.dart (`restoreSession` re-reads `my_account`/`my_profile`)
- test/auth_live_repository_test.dart (group names carry the phase number)
- lib/core/l10n/app_strings.dart (+hi, mr): `listingSuspendedNotice` (copy only; screens not wired yet)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Every account state restores correctly | 051: guest, new (needsProfile), published (active + profile id), suspended, deleted-elsewhere (signedOut, nothing retained) | Pass |
| No other provider's owner view | 051: switching the session to an account without a profile clears the previous profile and ids | Pass |
| Offline start-up | 051: restore while offline -> guest state, then recovers | Pass |
| Account recovery / phone change invalidate stale references | ownership is re-read on every restore; nothing is cached in the repository; recovery execution also deletes the old sessions (0028 test) | Pass |
| Paused / draft | the profile's own `status` is carried by `ProviderProfile`; `SessionStatus.active` covers draft/published/paused (the dashboard already reads `profile.status`) | Pass (existing UI) |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 051 group: 6 tests pass

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
- `SessionStatus.suspended` is new; the onboarding screen only compares against `signedOut`, so existing screens keep working, but no screen shows the suspended notice yet (UI wiring belongs with Workstream 7).
- "Deleted" is modelled as an account whose `my_account` returns null; a `ListingStatus.deleted` wire value does not exist (deletion is a row delete, backend-contract 4.6).

## Rollback / safe stop
Clear stale state and rebuild from verified identity (what `restore()` does first).

## Next action
Show the suspended notice on the dashboard (Workstream 7).
