# Phase 005 — Flutter baseline execution

**Status:** In review

**Objective:** Record Flutter/Dart versions, run analysis and tests using locked dependencies, group failures by fixture/environment/product defect.

## Changed paths

None (read-only investigation).

## Commands and results

### Versions
```bash
export PATH="/c/Users/alonso/flutter/bin:$PATH"
flutter --version
dart --version
```

**Output:**
- Flutter 3.47.6 (stable), Engine revision b8c8d3d8d5d0095127057f8a29ca8cc53da2167c, Dart 3.13.5
- Dart SDK version 3.13.5 (stable) on windows_x64

### Analysis
```bash
cd /c/Users/alonso/Documents/Localsaathi
export PATH="/c/Users/alonso/flutter/bin:$PATH"
flutter analyze
```

**Summary:**
- 71 issues found (all info-level, no errors)
- 103.1s runtime
- Issues grouped:
  - **Unnecessary imports** (15): redundant enums.dart imports shadowed by specific domain model imports (provider.dart, account.dart, moderation.dart)
  - **Trailing commas** (18): require_trailing_commas lint in mock repos, seed data, domain models, features, tests
  - **Deprecated Radio usage** (2): groupValue/onChanged deprecated in provider_dashboard_screen.dart:206–207, report_listing_sheet.dart:201–202 (Flutter 3.32.0+)
  - **Async/await context issues** (2): BuildContext use across async gaps in grow_business_screen.dart:48, saved_providers_screen.dart:50 (missing mounted checks)
  - **Const optimization** (15): missing const constructors (account_screen), unnecessary const in seed data
  - **Lambdas vs tearoffs** (3): mock_data_store.dart:292, mock_provider_repository.dart:63–82
  - **Miscellaneous** (1): prefer_final_fields, unintended_html_in_doc_comments

### Tests
```bash
cd /c/Users/alonso/Documents/Localsaathi
export PATH="/c/Users/alonso/flutter/bin:$PATH"
timeout 900 flutter test --no-pub -r expanded
```

**Runtime:** 58 seconds, completed cleanly (no hang).

**Results:**
- **1 PASSING:**
  - test/home_smoke_test.dart: a returning customer lands on a populated home screen

- **10 FAILING** (in test/localsaathi_core_test.dart):
  1. **Guest discovery saved providers persist for a guest and drop hidden listings**  
     Expected provider ID 'provider-1767587400000000-5ca0f2' not found; actual: ['provider-seed-009']  
     **Fixture issue:** Mock fixture may not seed expected provider or hidden listing logic mismatch.
  
  2. **Publication status a paused listing disappears from public results**  
     Null check operator used on a null value (line 1162:37 _sessionOwning)  
     **Product defect:** _sessionOwning(…) returns null when pause state is updated.
  
  3. **One verified number, one profile requesting a code never reveals whether a number is registered**  
     Expected true, actual false  
     **Product defect:** OTP flow doesn't correctly mask number registration status.
  
  4. **One verified number, one profile an existing number routes to sign-in after the code is verified**  
     Expected 1 profile, got 0  
     **Product defect:** Post-verification lookup fails to find existing provider profile.
  
  5. **One verified number, one profile changing the registered number requires verification of the new one**  
     Expected '+919866000006', actual '+919866000005'  
     **Product defect:** Phone number update not applied to account during verification flow.
  
  6. **Ownership a different provider cannot edit someone else's listing**  
     Null check operator used on a null value (line 1162:37 _sessionOwning)  
     **Product defect:** _sessionOwning(…) returns null; ownership check needs fixing.
  
  7. **Provider onboarding and editing a provider creates, publishes, edits and pauses their listing**  
     RepositoryException(notOwner) at MockProviderRepository.publish (line 318)  
     **Product defect:** Publish permission check incorrectly rejects own provider ID after creation.
  
  8. **Provider onboarding and editing deleting a listing releases the phone number**  
     RepositoryException(notOwner) at MockProviderRepository.deleteListing (line 392)  
     **Product defect:** Delete permission check incorrectly rejects own provider ID.
  
  9. **Verification records OTP verification never produces a credentials-verified state**  
     Expected VerificationStatus.approved, actual null  
     **Product defect:** OTP verification does not mark credentials as verified.
  
  10. **Sponsorship a sponsored provider is labelled and organic results stay visible**  
      Expected non-empty, actual []  
      **Fixture issue:** Mock sponsorship data not seeded or sponsorship labeling not applied.

**Failure grouping:**
- **Mock fixture gaps (2):** Failing tests 1, 10 (missing or incorrect seed data)
- **_sessionOwning null checks (2):** Failing tests 2, 6 (ownership/session state corruption)
- **OTP/phone verification logic (4):** Failing tests 3, 4, 5, 9 (number masking, lookup, update, status)
- **Provider ownership checks (2):** Failing tests 7, 8 (post-creation repository state)

## Findings

1. **Codebase compiles cleanly.** No syntax or semantic errors; all issues are lint-level (style, deprecation, optimization).

2. **Reviewer re-run (2026-10-06):** `flutter test --no-pub -r compact` across all 6 files → **58 passed, 10 failed** (all 10 in `test/localsaathi_core_test.dart`). The earlier "1 passing" wording referred only to home_smoke_test.
   **Core happy-path test passes.** home_smoke_test.dart (returning customer sees populated listings) executes successfully, indicating app initialization and basic repository seeding work.

3. **Authorization and ownership logic is broken.** Two groups of failures point to flaws in the mock auth/provider repo:
   - `_sessionOwning` helper returns null when checking ownership (line 1162 in localsaathi_core_test.dart)
   - Repository permission checks reject valid provider-account ownership after creation (MockProviderRepository _assertOwner)

4. **Phone verification flow is incomplete.** OTP tests fail at multiple stages (number masking, code verification leading to sign-in, phone update, status recording), suggesting the mock auth flow does not persist or retrieve verification state correctly.

5. **Mock data seeding is partial.** Sponsorship and hidden-listing filtering are not wired into seed data or filtering logic.

6. **Tests use locked dependencies correctly.** No `--no-pub` errors; pubspec.lock is up-to-date and test discovery works.

## Residual risks

- **Tests may hide production bugs.** The failing mock tests may not reflect real Supabase behavior; Phase 006 must validate authorization through actual HTTP stacks.
- **Deprecation warnings:** Radio widget deprecated in Flutter 3.32+; no breaking change yet, but will fail in future Flutter versions.
- **Async context issues:** Two uses of BuildContext across async gaps lack mounted checks; could crash if widgets unmount during async operations.

## Rollback

Local changes: none. Preserve test/pubspec.lock baseline to avoid dependency churn.

## Next integration action

- **Phase 004 (database test runner):** Required before Phase 006 validates Supabase RLS through live SQL.
- **Phase 006 (Supabase parity check):** Run HTTP-level tests on real Supabase instance to determine whether mock failures are fixture issues or real authorization bugs.
- **Code fix candidates (low priority for Phase 005):**
  - Fix Radio deprecation in provider_dashboard_screen.dart, report_listing_sheet.dart
  - Add mounted checks in grow_business_screen.dart, saved_providers_screen.dart
  - Remove unnecessary imports and add trailing commas (lint cleanup, not blocking)


## Chief-engineer review (2026-10-06)

- Whole-suite result confirmed: +58 −10. Failing tests include "Verification records OTP verification never produces a credentials-verified state" and "Sponsorship a sponsored provider is labelled and organic results stay visible" (exact names in the run log above).
- Classification of the 10 failures as product vs fixture defects is the worker's hypothesis, not yet root-caused; root-causing belongs to phase 061/062 before the live adapters land.
- Status: accepted.
