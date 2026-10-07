# Phase 056 Evidence - Reviewer access without backdoors

**Status:** Done locally (the staging reviewer environment needs a Supabase staging project and the SMS fake/vendor) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Define a minimally privileged reviewer path without universal codes, magic numbers or admin bypasses, and guard against them.

## Changed paths
- backend/supabase/config.toml (the fixed `+911234500000 = "123456"` test OTP block REMOVED)
- backend/supabase/config.local-test-otp.toml.example
- backend/scripts/check-identity-config.mjs
- backend/test/identity-config.test.mjs
- docs/identity-operations.md (section 4)
- docs/backend-contract.md (section 3.0 / 3.2 text)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| No universal fixed codes shipped | config.toml has no `test_otp` block (it could be pushed to a hosted project by `supabase config push`: threat TH-03, phase 012); demo code exists only in `LS_ENV=demo` builds and is rejected by live auth (auth_selection_test) | Pass |
| Guard fails on regressions (mutation checks) | identity-config.test.mjs: injected `[auth.sms.test_otp]`, phone=code line, inline hook secret, enabled hook without env secret, pasted JWT, simulated-OTP read outside the demo graph, service-role key in Dart -> each caught; comments mentioning the words do not trip it; the repo is clean | Pass (6 tests) |
| Review instructions work and grant no unrelated private access | documented procedure uses a separate staging project, a synthetic reviewer provider, the project's own test-number feature and no admin role | DOCUMENTED ONLY: cannot be exercised without a project |

## Commands run for this phase (actual results)
- `node scripts/check-identity-config.mjs` -> `Identity config: PASS`
- `node --test test/identity-config.test.mjs` (in backend/) -> 6 tests pass

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
- The review environment itself is not built: it requires a Supabase staging project, the Play review account details and (optionally) the fake sender. Marked as a deployment task.
- Supabase's hosted "test phone numbers" feature (fixed code for listed numbers on that project) is the intended mechanism for reviewers, restricted to a throw-away staging project; production must never have it. The guard cannot see dashboard settings, so the release checklist must include "no test numbers configured on production".
- Local developers now have to copy the example block into a throw-away config to use a fixed local OTP; this is an intentional friction.

## Rollback / safe stop
Rotate or delete the staging test number after review.

## Next action
Create the staging project and a synthetic reviewer profile (phase 060 checklist); add the dashboard check to the release checklist.
