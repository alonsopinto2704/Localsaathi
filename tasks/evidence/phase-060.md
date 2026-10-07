# Phase 060 Evidence - Identity readiness gate

**Status:** Done locally (staging verification NOT performed: blocked on a Supabase staging project, an SMS vendor/DLT approval and Docker) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Review SMS configuration, real adapter behaviour, session persistence, recovery, privileged MFA and budget controls; demonstrate the demo code cannot authenticate in production; record staging delivery evidence separately from unresolved provider setup.

## Changed paths
- (gate; no new feature code) backend/scripts/db-inventory.mjs (bug fix: the view label broke `has_table_privilege`, so the inventory crashed since the audit follow-up)
- docs/identity-operations.md (section 6: staging checklist)
- backend/scripts/http-authz-pack.mjs (identity probes added, unexecuted)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| SMS configuration reviewed | phase 043: hook fails closed, secrets via env only, fake sender for staging, vendor unprovisioned | Reviewed; vendor open |
| Real adapter behaviour | Supabase adapter compiled/analyzed and exercised through a fake gateway; NOT run against GoTrue | LOCAL ONLY |
| Session persistence / recovery / privileged MFA / budget | phases 049, 053, 054, 047: tests listed in their files | Pass (local) |
| Demo code cannot authenticate in production | auth_selection_test: production/staging never select the mock (with and without config); the live repo has an empty `simulatedCode` and rejects `123456`; the dev banner is demo-only; `check-identity-config.mjs` guards config.toml and the Dart source | Pass |
| Critical negative scenarios | wrong/expired/replayed codes, rate limits, enumeration, revoked sessions, stale sessions, non-admin/aal1 admin, cross-account deletion, impersonated recovery, phone-change conflicts: all tested in 041-059 | Pass (local) |
| Staging verification | not performed | BLOCKED |
| Production registration closed until controls pass | no production project exists; `LS_ENV` defaults to demo; non-demo builds fail closed | Holds |

## Commands run for this phase (actual results)
- `node backend/scripts/db-inventory.mjs` -> exit 0 (was a stack trace); new private tables show no anon/authenticated privileges; new public functions are service-role-only except the intended authenticated ones
- See the verification table below for the full suite.

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
- **Staging evidence: none.** No delivery latency, no real OTP, no hosted behaviour of the hook, `amr` claims, GoTrue phone change or recovery SQL has been observed. Everything is local PGlite/Node/Flutter with fakes.
- Unresolved provider-account setup: SMS vendor + DLT (product owner), Supabase staging project (product owner / integration engineer), TalkBack pass (QA), native-language review (language reviewer), alert wiring (backend/security).
- Human sign-off pending (product owner and backend/security engineer).

## Rollback / safe stop
Keep production registration closed until the staging checklist in docs/identity-operations.md section 6 passes.

## Next action
Provision the staging project and run section 6; then flip this phase to a full Done and start Workstream 4 phase 061 against live auth.
