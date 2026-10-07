# Phase 057 Evidence - Deletion request endpoint

**Status:** Done locally (Edge Function and storage cleanup unexecuted on a real project) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Harden delete-account with a verified caller, recent authentication, stable safe errors, idempotency and a job id, coordinated with storage cleanup and retained records.

## Changed paths
- backend/supabase/functions/delete-account/logic.ts
- backend/supabase/functions/delete-account/index.ts
- backend/supabase/migrations/20261007000029_deletion_jobs.sql
- backend/supabase/tests/database/0023_deletion_jobs.test.sql
- backend/test/delete-account.test.mjs
- lib/data/supabase/supabase_provider_auth_repository.dart (`deleteAccount`)
- lib/app/controllers/session_controller.dart (reauth/failed deletion leaves the account and draft untouched)
- test/support/fake_auth_gateway.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Retries preserve one deletion state | 0023: same/different key converge on one job (attempts counted); Node: failed storage then retry -> one job, completes; Dart: retry reuses the same key and does not request a second grant | Pass |
| Cross-account deletion attempts fail | Node: a victim id in the body is ignored (only the JWT user is deleted); B's deletion needs B's grant; 0023: users cannot call `begin_account_deletion` (42501) | Pass |
| Verified caller + recent auth | JWT verified via Auth; first request consumes a `delete_account` grant -> 403 `reauth_required` without one | Pass |
| Stable safe errors | responses are `{error: code}` only; thrown internals (relation names, passwords) never reach the body; failure code stored as `^[a-z_]{1,40}$` | Pass |
| Coordination with blob cleanup and retained records | order: storage objects, then auth user (cascade), then job completed; receipts keep user id + timestamps only, purged after 30 days; existing delete trigger still snapshots reports/queues cleanup | Pass (logic); real storage untested |
| Retry after success / lost response | token is dead (401): Dart treats a 401 on its own retry as "already deleted" and finishes local sign-out | Pass |

## Commands run for this phase (actual results)
- `npm --prefix backend run test:db` -> `ok 0023_deletion_jobs.test.sql (17 tests)`
- `node --test test/delete-account.test.mjs` (in backend/) -> 10 tests, 10 pass
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 057 group: 4 tests pass

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
- `index.ts` (Deno + supabase-js) was not executed. The previous version's storage loop was kept; it is the part most likely to need adjustment against the real Storage API (listing folders vs files).
- If the auth delete succeeds but marking the job `completed` fails, the job stays `storage_cleaned`; the user is gone, so no retry can reach it. Harmless (receipt only) but visible in the table.
- Server-side deletion does not remove data held by backups/log retention; the privacy text must say so (legal review).

## Rollback / safe stop
Pause before irreversible removal if prerequisites fail: every failure before the auth delete leaves the account intact and retryable.

## Next action
Deploy to a disposable project, delete a test account that has photos, confirm the buckets are empty (carried from phase 040).
