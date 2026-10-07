# Phase 041 Evidence - Live auth repository skeleton

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
A Supabase-backed `ProviderAuthRepository` behind the existing contract, chosen by an explicit build environment, failing closed when production configuration is missing, with guest discovery untouched.

## Changed paths
- lib/data/supabase/auth_config.dart
- lib/data/supabase/auth_gateway.dart
- lib/data/supabase/auth_selection.dart
- lib/data/supabase/auth_bootstrap.dart
- lib/data/supabase/supabase_auth_gateway.dart
- lib/data/supabase/supabase_provider_auth_repository.dart
- lib/app/app_dependencies.dart (optional `auth` override; default stays the mock)
- lib/main.dart (non-demo builds use `buildLiveAuth`)
- lib/features/provider/onboarding/onboarding_widgets.dart (the "code is always 123456" banner is shown only when `LS_ENV=demo`)
- lib/domain/models/account.dart (RepositoryErrorCode.reauthRequired/unavailable)
- lib/domain/repositories/auth_repository.dart (PhoneInputError.rateLimited/reauthRequired, OtpChallengeResult.retryAfter, SessionRevocationNotifier)
- pubspec.yaml / pubspec.lock (+`flutter_secure_storage`, used by phase 049)
- test/auth_selection_test.dart
- test/auth_live_repository_test.dart (group names carry the phase number)
- test/support/fake_auth_gateway.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Contract tests choose the correct implementation per environment | auth_selection_test: parse (6 spellings), default build = demo + `MockProviderAuthRepository`, demo ignores live config, staging/production + valid config = live repo | Pass (15 tests) |
| Fail closed when production config is missing | auth_selection_test: no url, no key, http url, local http in production, service-role JWT, `sb_secret_` key, empty staging all yield `FailClosedAuthRepository`; guests keep `restoreSession() == null`; requestOtp fails; verifyOtp/registerProfile throw; the reason string contains no configured value | Pass |
| SDK types do not leak into screens | Only `supabase_auth_gateway.dart` imports the SDK auth types; everything else sees `GatewaySession`/`GatewayException`/`GatewayRpcException` | Pass (by construction; analyze clean) |
| Demo code cannot authenticate against live | auth_selection_test: live repo returns an empty `simulatedCode`; `123456` rejected; session stays null | Pass |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/auth_selection_test.dart` -> `+15: All tests passed!`
- `flutter test --no-pub test/auth_live_repository_test.dart` -> `+41: All tests passed!` (041 group: 2 tests)

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
- The Supabase SDK adapter (`SupabaseAuthGateway`, `initializeSupabase`) compiles and analyzes but was NOT run against GoTrue/PostgREST (no Docker, no project). Error-code mapping (`otp_expired`, `over_sms_send_rate_limit`, `phone_exists`, ...) follows GoTrue's documented codes from the installed `gotrue-2.27.2` package and general knowledge; confirm against a real project.
- `SUPABASE_ANON_KEY` is passed as `publishableKey`; both legacy JWT anon keys and new `sb_publishable_` keys are accepted, `service_role` JWTs and `sb_secret_` keys are refused.
- Assumption: a staging/production build with live auth still uses the mock data repositories until Workstream 4 (phase 061); sign-in works but listing writes remain mock. This is deliberate and recorded so nobody ships that combination.
- ASSUMPTION: `LS_ENV` defaults to `demo` (mock mode stays the default per the brief), so the release pipeline must pass `LS_ENV=production` explicitly; phase 287 (artifact guardrails) should fail a release build that lacks it.

## Rollback / safe stop
Build with `LS_ENV=demo` (the default): the mock graph is used exactly as before. Nothing persisted by the mock changes.

## Next action
Phase 061: make `AppDependencies` environment-aware for all repositories; run the adapter against a disposable Supabase project.
