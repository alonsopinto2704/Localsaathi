# Phase 058 Evidence - Accessible localized verification

**Status:** Done locally (TalkBack on a physical device not run) · **Reviewer:** Opus chief engineer review pending · **Human sign-off:** pending

## Objective
The verification flow works with large text, paste, keyboard navigation and assistive-technology semantics in English, Hindi and Marathi, without SMS-inbox permission.

## Changed paths
- lib/features/provider/onboarding/onboarding_widgets.dart
- lib/features/provider/onboarding/provider_onboarding_screen.dart
- lib/core/l10n/app_strings.dart
- lib/core/l10n/app_strings_hi.dart
- lib/core/l10n/app_strings_mr.dart
- test/otp_panel_accessibility_test.dart

## Acceptance evidence
| Requirement | Evidence | Result |
|---|---|---|
| Large fonts / small phone | 12 widget tests at 360x640 and 2x text for en/hi/mr, phone and code steps: no overflow. The tests FOUND a defect (the "Code sent to ... / Change number" row overflowed by 53 px at 2x) and it was fixed (Row -> Wrap) | Pass (+12) |
| Paste / keyboard | phone and code fields accept pasted separators, spaces and Devanagari/Arabic-Indic/full-width digits and drop letters; `done` key submits; `oneTimeCode` and `telephoneNumberNational` autofill hints set | Pass |
| Screen-reader semantics in all languages | the resend control exposes a stable "wait" description and enabled=false while waiting, plain label when ready; per-second text is excluded from semantics; labelled fields; verified with the semantics tree in en/hi/mr | Pass (semantics tree) |
| Slow SMS / failed resend | localized delayed-SMS help, visible countdown, rate-limit and re-auth messages (en/hi/mr); failed resend now shows its real error instead of "invalid code" | Pass |
| No unnecessary SMS permission | AndroidManifest.xml has no READ_SMS/RECEIVE_SMS (grep returned nothing); the code is typed or pasted | Pass |
| Fallback if segmented input fails | a single text field is already used (no segmented control to fail) | N/A |

## Commands run for this phase (actual results)
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
- "The complete flow works with screen-reader navigation" is NOT proven: widget semantics tests are not TalkBack. A manual TalkBack pass on a device in all three languages is required before this phase is signed off by a human.
- Hindi and Marathi strings were written by the implementing agent; they need native-language review (technical terms such as "SMS" are left in Latin script).
- The 6-digit hint is hard-coded in the strings (matches `otp_length = 6`).

## Rollback / safe stop
A single code field is the fallback and the current implementation.

## Next action
Manual TalkBack walkthrough and native review (add screenshots to this file).
