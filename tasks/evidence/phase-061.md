# Phase 061 Evidence - Environment-aware composition root

**Status:** Done locally. Staging verification BLOCKED (no hosted Supabase project; the live SDK path `initializeSupabase` was never run against a server). **Reviewer:** pending. **Human sign-off:** pending.

## Objective
Explicit demo / staging / production selection of the whole repository graph; no unconditional mock selection; a missing or broken backend configuration produces an actionable blocked state, never fictional providers; a local-storage failure cannot change which data is shown.

## Changed paths
- lib/app/app_dependencies.dart (`AppDependencies.forEnvironment`, private `_live`, `BackendBlockedException`; `mock()` unchanged and now only the demo/test graph)
- lib/app/backend_blocked_app.dart (new: plain English blocked screen with the non-secret reason)
- lib/main.dart (storage failure -> in-memory preferences in EVERY environment; live build with bad config / failed start -> `BackendBlockedApp`; the old catch-all fallback to `AppDependencies.mock` is now demo-only)
- lib/data/supabase/auth_bootstrap.dart (`buildLiveAuth` replaced by `startLiveBackend` returning a `LiveBackend{data, auth}` or null; same fail-closed auth selection)
- lib/data/supabase/data_gateway.dart (new narrow `DataGateway`: `rpc`, `selectRows`)
- lib/data/supabase/supabase_auth_gateway.dart (also implements `DataGateway`; adds `selectRows`)
- test/live_composition_test.dart, test/support/fake_data_gateway.dart

## Behaviour
| Build | Result |
|---|---|
| `LS_ENV=demo` (default) | mock graph, as before |
| staging/production, config invalid (missing/http/service-role key) | `BackendBlockedException(reason)` -> blocked screen |
| staging/production, config valid but SDK start fails | blocked screen ("the backend client failed to start") |
| staging/production, started | live locations, catalog, discovery, owner profile, bookmarks, identity |
| storage cannot open | in-memory preferences; backend choice unchanged |

Remaining mock-backed in the live graph (over an EMPTY unseeded store, so no fictional providers, but also not yet sent to the backend): reports, engagement, promotions, consents, verification, credentials. Customer reports in a live build are therefore NOT delivered until their phases land. This must be fixed before any release.

## Commands run (actual results)
- Baseline before edits: `flutter test --no-pub -r failures-only` -> `+360: All tests passed!`; `flutter analyze` -> `73 issues found.` (all info)
- `flutter test --no-pub test/live_composition_test.dart -r failures-only` -> `+8: All tests passed!`
- Final: `flutter test --no-pub -r failures-only` -> `+408: All tests passed!`; `flutter analyze` -> `73 issues found.` (all info, none in new files)

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Missing production config -> actionable blocked state, not fictional providers | composition test (6 bad configs x 2 envs blocked; reason has no URL/key value); blocked-screen widget test | Pass (local) |
| Demo identities never launch a real contact action | live profiles are forced `isDemoProfile=false` (phase 062) and the live graph holds no seeded profiles (`dataStore.profilesById` empty) | Pass (local) |
| Storage exception cannot silently show demo data | main.dart separates preference storage from backend; test builds a live graph with `persist:false` | Pass (local) |
| Backend failure is an error, not mocks | test: failing gateway makes search / activeLaunchCity throw | Pass (local) |
| Guest, owner, offline, empty, error, account-switch | covered across 061-067 tests with fakes; no staging run | Pass (local) / staging BLOCKED |
| Staging integration check | not performed | BLOCKED |

## Remaining uncertainty
- `LS_ENV` still defaults to `demo`; a release pipeline that forgets `--dart-define=LS_ENV` ships the mock build (already recorded in phase 041; phase 287 should fail such a build).
- `SupabaseAuthGateway.selectRows` / `initializeSupabase` compile and analyze but were never run against PostgREST.
- `main()` itself is not unit-tested (needs the platform bindings); its pieces (`forEnvironment`, `BackendBlockedApp`) are.

## Next action
Provision the staging project, run the app with `LS_ENV=staging` and real `SUPABASE_*` defines, and replace the remaining mock repositories (reports first).
