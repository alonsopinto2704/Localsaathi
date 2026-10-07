# Phase 042 Evidence - Phone normalization and entry

**Status:** Done locally · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
One canonical E.164 form for Indian mobiles, strict about what is accepted, with Dart and the server agreeing on a shared fixture.

## Changed paths
- lib/core/utils/phone_number.dart (Unicode digits -> ASCII, separators, zero-width/bidi characters, trunk 0 after +91, letters rejected instead of silently dropped)
- docs/contracts/fixtures/phone-cases.json (31 cases)
- test/phone_fixtures_test.dart
- backend/test/phone-fixtures.test.mjs
- backend/supabase/migrations/20261007000024_otp_guard.sql (`private.is_supported_mobile`)
- backend/package.json (`test`, `test:db`, `test:unit`)
- lib/features/provider/onboarding/onboarding_widgets.dart (phone field accepts pasted separators/any digit script; length cap 24)

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Dart and server fixtures agree on valid and invalid normalized input | phone_fixtures_test replays every case; phone-fixtures.test.mjs runs each `server` value through `private.normalize_e164` + `private.is_supported_mobile` on the migrated PGlite DB | Pass (Dart +36, Node 2 tests) |
| Pasted separators, Unicode digits, invalid lengths, international boundaries | cases: spaces/dots/dashes/brackets, Devanagari, Arabic-Indic, full-width, ZWSP, NBSP, 00/0/91 prefixes, +1/+44/+971, 9/11 digits, leading 5 | Pass |
| Never a fixed production test number | fixture numbers are the synthetic 9000 0xxxxx range; no bypass added; `check-identity-config.mjs` rejects phone=code entries in config.toml | Pass |
| Preserve entered text when validation changes | the controller never clears the phone field on a validation error (unchanged); panel test types/pastes without resets | Pass |

## Commands run for this phase (actual results)
- `flutter test --no-pub test/phone_fixtures_test.dart` -> `+36: All tests passed!`
- `node --test test/phone-fixtures.test.mjs` (in backend/) -> both tests pass

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
- A real defect was fixed: `98765abc43210` used to normalise to a valid number because letters were stripped; it is now `notNumeric`.
- `+91 098765 43210` (trunk 0 after the country code) is accepted and normalised, matching common Indian typing; this is a product decision, change the fixture and tests together if it should be rejected.
- Only +91 is supported (as before); adding a country is a data change in `PhoneUtils.supportedDialCodes` plus the SQL regex.

## Rollback / safe stop
Revert `phone_number.dart`; the SQL function is additive and unused by anything else.

## Next action
Phase 058 covers localized guidance; extend the fixture when a second country is added.
