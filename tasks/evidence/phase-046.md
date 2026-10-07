# Phase 046 Evidence - Resend and delayed delivery

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Resend pacing coordinated with server policy, duplicate submits disabled, delayed-SMS guidance, accessible loading, aggregate failure counters without message contents.

## Changed paths
- lib/data/supabase/otp_cooldown.dart
- lib/data/supabase/supabase_provider_auth_repository.dart (in-flight de-duplication, cooldown, rate-limit mapping)
- lib/app/controllers/session_controller.dart (busy guard, `resendWaitSeconds`)
- lib/features/provider/onboarding/onboarding_widgets.dart
- lib/features/provider/onboarding/provider_onboarding_screen.dart
- lib/core/l10n/app_strings.dart
- lib/core/l10n/app_strings_hi.dart
- lib/core/l10n/app_strings_mr.dart
- backend/supabase/migrations/20261007000024_otp_guard.sql (`otp_record_delivery`, `private.otp_stats`)
- test/auth_live_repository_test.dart (group names carry the phase number)
- test/otp_panel_accessibility_test.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Rapid taps cannot evade limits | 046: three simultaneous `requestOtp` -> exactly one send; the next within 60 s is `rateLimited` with a retry-after | Pass |
| App restarts cannot reset the visible wait | 046: a new repository sharing only the key-value store is still `rateLimited`; the store holds one timestamp, no number or code | Pass |
| Server retry-after respected | 046: 5-minute server limit stretches the wait; allowed after it passes | Pass |
| Duplicate submits disabled / accessibility while loading | `SessionController` ignores a second tap while busy; resend button disabled during the wait with a stable spoken description (058 tests) | Pass |
| Aggregate failures without contents | `otp_stats` counters (`delivery_*`, `denied_*`) in 0018 test | Pass |
| Delayed messages explained | localized `otpDelayedHelp` shown on the code step in en/hi/mr | Pass |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_live_repository_test.dart` -> 046 group: 3 tests pass
- `flutter test --no-pub test/otp_panel_accessibility_test.dart` -> `+12: All tests passed!`

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
- The countdown uses the wall clock (`DateTime.now`); backgrounding the app does not reset it (it is computed from a timestamp), but a manual clock change could shorten the visible wait. The server limit is unaffected.
- Hindi/Marathi copy was written by the implementing agent and needs native-language review (also noted in 058).

## Rollback / safe stop
Bounded manual retry after the cooldown (the existing resend button).

## Next action
Native-language review of the new strings.
