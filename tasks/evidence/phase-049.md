# Phase 049 Evidence - Secure session persistence

**Status:** Done locally (on-device Keystore behaviour unverified) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
Platform-backed storage for the auth session, separated from bookmarks and preferences; owner-specific state cleared on logout/account switch.

## Changed paths
- lib/data/supabase/secure_session_storage.dart (`SecretStore`, `PlatformSecretStore`, `SecureSessionStorage`)
- lib/data/supabase/supabase_auth_gateway.dart (`initializeSupabase` installs it)
- pubspec.yaml / pubspec.lock (`flutter_secure_storage ^10.3.4`)
- lib/app/controllers/session_controller.dart (a draft belonging to a different number is dropped on verify)
- backend/scripts/check-identity-config.mjs
- test/session_storage_and_revocation_test.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| SDK defaults evaluated | supabase_flutter 2.18 defaults to `SharedPreferencesLocalStorage` (plain XML); replaced via `FlutterAuthClientOptions.localStorage` | Done |
| Session secrets separate from bookmarks/preferences | test scans `lib/data/supabase/`: only `otp_cooldown.dart` (a timestamp) and the bootstrap use the key-value store; no file mentions both a token and shared_preferences | Pass |
| Second account cannot recover the first's token | A signs out -> store empty -> B signs in -> only B's value exists | Pass |
| Unsafe storage requires re-authentication | unreadable keystore -> token treated as absent; unwritable -> kept in memory only, nothing falls back to plain storage | Pass |
| Owner-specific drafts cleared | 051 test: verifying a different number deletes the previous number's draft; sign-out/delete already cleared it (phase 003 test) | Pass |
| No credential evidence / raw conversations in generic storage | none exist yet; the guard test fails if session code starts using `key_value_store`/`shared_preferences` | Pass (forward guard) |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/session_storage_and_revocation_test.dart` -> `+6: All tests passed!`

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
- `flutter_secure_storage` was added with `flutter pub add` (needed network); Android build with the new plugin was NOT run (the Android release build has never run since the Gradle upgrade: phase 281). Its Keystore behaviour on real devices, backup rules (`android:allowBackup`) and re-install behaviour need a device test.
- Web builds are out of scope for the live session storage.

## Rollback / safe stop
Require re-authentication when secure storage is unsafe (implemented: reads fail closed).

## Next action
Device test: sign in, kill app, relaunch (session restored), clear data (signed out). Review `android:allowBackup` for the secure-storage file.
