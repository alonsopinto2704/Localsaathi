# Phase 047 Evidence - OTP pumping protection

**Status:** Done locally (alert delivery and hosted behaviour need a Supabase project) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Per-number, number-block and global spend controls at a boundary direct Auth requests cannot bypass, with thresholds, alert ownership and a circuit breaker.

## Changed paths
- backend/supabase/migrations/20261007000024_otp_guard.sql (`otp_limits`, `otp_settings`, `otp_send_log`, `otp_stats`, `otp_send_gate`, `otp_breaker_reset`, `purge_otp_send_log`)
- backend/supabase/tests/database/0018_otp_guard.test.sql
- backend/supabase/functions/send-sms-hook/ (the call site)
- backend/supabase/config.toml (`[auth.rate_limit]`)
- backend/scripts/http-authz-pack.mjs (anon/authenticated cannot call the gate)
- docs/identity-operations.md (section 1)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Synthetic abuse hits hard limits | 0018: 4th code to one number/hour refused; 9th/day refused (8 allowed); 31st code into one 10,000-number block/hour refused; global 5/hour (lowered for the test) opens the breaker for everyone | Pass (24 assertions) |
| Legitimate shared-network users retain recovery | limits are per number and block, not per IP: another block is still served; after the window the same number is allowed again; breaker closes after its period or `otp_breaker_reset()` | Pass |
| Cannot be bypassed by direct Auth requests | enforced inside the Send SMS hook which Auth calls for every code; gate callable by service_role only (anon and authenticated get 42501) | Pass (SQL); hook wiring unexecuted |
| Privacy-aware signals | log keeps a keyed SHA-256 of the number and an 8-character block, purged after 48 h; no number or code stored | Pass |
| Thresholds, alert ownership, circuit breaker | defaults in `private.otp_limits`; breaker audited as `otp_breaker_opened`; owner: backend/security engineer; alert wiring listed as a deployment task | Documented; alert NOT wired |

## Commands run for this phase (actual results)
- `npm --prefix backend run test:db` -> `ok 0018_otp_guard.test.sql (24 tests)`

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
- No network/IP signal exists in the Send SMS hook payload, so per-IP limits rely on Auth's own `[auth.rate_limit]` settings (values committed in config.toml; the hosted dashboard values must match). The "network/risk" control implemented here is the number-block heuristic. This is a real limit of the platform hook, recorded rather than hidden.
- Default thresholds (3/8/30/300/1500) are conservative guesses for a one-city launch, not measured; tune with real traffic. Spend per message is unknown until a vendor quote exists.
- The advisory lock serialises gate decisions; throughput is far above OTP rates, but re-measure if sign-ins ever exceed a few per second.

## Rollback / safe stop
Stop outbound OTP: `update private.otp_settings set breaker_open_until = now() + interval '1 day'` (users see the generic "temporarily unavailable"), or disable the hook.

## Next action
Wire alerts on `otp_breaker_opened` and `denied_*` counters at deployment; confirm Auth rate-limit values in the hosted dashboard.
