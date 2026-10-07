# Phase 053 Evidence - SIM-loss recovery workflow

**Status:** Done locally (support tooling UI and independent-contact process are operational work) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
A support-assisted recovery case with minimal evidence, fraud review, delayed high-risk transfer, separation of preparation from transfer, and a record of reviewer rationale.

## Changed paths
- backend/supabase/migrations/20261007000028_recovery_cases.sql
- backend/supabase/tests/database/0022_recovery_cases.test.sql
- backend/scripts/supabase-stub.sql (adds `auth.sessions` for the harness)
- docs/identity-operations.md (section 3)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| An impersonation attempt cannot transfer a listing using public facts | 0022: a claimant with a perfect statement cannot approve or execute (`not_owner`); nothing moves without an administrator's written decision AND a 7-day wait AND a second execution step | Pass (27 assertions) |
| Separate preparation from transfer | open/review (preparation) vs `admin_execute_recovery` (transfer) are different functions; execution before approval or during the wait -> `conflict` | Pass |
| Freeze disputed transfers | 0022: the owner sees the request (no claimant details), disputes, and execution is refused even after the wait | Pass |
| Minimal evidence; no numbers | statement 20-1000 chars, phone digits refused; support queue shows only the last two digits of the claimant number | Pass |
| Reviewer rationale and resolution recorded | rationale >= 20 chars stored on the case; every step audited (2 opened, 2 approved, 1 disputed, 1 executed, 1 phone change) | Pass |
| Outcome | original account (and profile row) keeps its owner; its login number becomes the claimant's verified number; its sessions are deleted; claimant's empty account removed; listing pauses and phone consent resets | Pass |
| Stale administrator session | 0022: TOTP proof 1 h old -> `reauth_required` | Pass |
| Abuse limits | max 3 cases/claimant/day, 5/listing/30 days, one case per verified claimant without a listing | Pass (limits coded; rate-limit branches covered by code review, not a test) |

## Commands run for this phase (actual results)
- `npm --prefix backend run test:db` -> `ok 0022_recovery_cases.test.sql (27 tests)`

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
- The execution step writes `auth.users.phone` directly and deletes the claimant row in SQL. In real GoTrue a phone user also has an `auth.identities` row (provider `phone`); whether sign-in by the new number resolves to the original user after this SQL change must be rehearsed on a real stack. If not, the function must also update `auth.identities`. NOT verified.
- Independent contact with the business (the main anti-fraud control) is a human process described in docs/identity-operations.md; no tooling enforces it.
- No admin UI exists; support uses the RPCs from an authenticated MFA session (admin console is a later workstream).
- The existing owner can only dispute if they can still sign in or reach support; a fully locked-out true owner relies on support's outreach during the 7 days.

## Rollback / safe stop
Freeze disputed transfers under the existing owner (implemented: `dispute_recovery_case`, plus support can reject any open or approved case).

## Next action
Rehearse on a real stack (identities row), then build the support console.
