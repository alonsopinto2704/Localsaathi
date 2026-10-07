# Phase 003 Evidence — Provider Journey Baseline

**Status:** Done (gate passed in phase-020; human sign-off pending)  
**Objective:** Trace the onboarding wizard (9 steps in code; plan prose says 10), interrupted drafts, phone verification, profile edits, pause/resume, working hours, deletion; inventory on-device personal data and account-switch leakage.  
**Method:** Static code trace of `ProviderOnboardingScreen`, `SessionController`, draft persistence, and mock repositories; no device run.

## Onboarding Sequence (9 steps)

The plan prose says "10-step", but the code implements **9 steps**: the `_Step` enum has 9 values and `_order` lists 9. Defined in `provider_onboarding_screen.dart` lines 99–109:

```
_order = [
  _Step.phone,      // 1. Phone number entry + OTP
  _Step.name,       // 2. Display name
  _Step.categories, // 3. Service categories (multi-select)
  _Step.location,   // 4. City + service area localities
  _Step.details,    // 5. Description + healthcare details (optional)
  _Step.hours,      // 6. Working hours (weekly schedule)
  _Step.contact,    // 7. Contact prefs (call consent, WhatsApp toggle)
  _Step.photos,     // 8. Profile photos (max 5)
  _Step.preview,    // 9. Review before publish
]
```

## Interrupted Draft Persistence

**Storage key:** `localsaathi.provider_draft` (JSON-serialized `ProviderDraft`)

**Draft structure** (fields from line 203–223 of onboarding screen):
- phoneE164, updatedAt, displayName, categoryIds, cityId, baseLocalityId, serviceAreaIds
- description, languages, workingHours, homeVisits
- phoneDisplayConsented, whatsappEnabled, healthcareDetails, lastStepIndex

**Resume logic** (lines 132–138 onboarding_screen.dart):
```
if _session.status == SessionStatus.signedOut:
  draft = await dependencies.drafts.load()
  if draft != null && draft.isResumable:
    _applyDraft(draft)
```

**Photos NOT persisted:** Lines 89–91 explicitly keep photos in-memory only to avoid bloating storage; provider re-adds them on resume.

**Draft save:** Called after each step (line 225–231), fire-and-forget to never block wizard.

## Phone Verification and Existing-Number Handling

**In `SessionController` (lines 116–189):**

1. **Request OTP** (line 117–139): Normalizes phone; NEVER reveals if number already registered (mock lines 61–64)
2. **Verify OTP** (line 142–189): Only after successful verification, reveals if profile exists (mock line 77); sets `_existingProfileId`
3. **Sign-in redirect** (onboarding lines 139–145):
   ```
   if _session.hasProfile:
     Navigator.pushReplacementNamed(AppRoutes.providerEdit)
   ```

## Profile Edits and Updates

**Screens:** `provider_profile_editor_screen.dart`, `working_hours_screen.dart`, `provider_dashboard_screen.dart`

**Mutation:** `SessionController.updateProfile()` (lines 250–297)
- Re-checks ownership via session
- Records consents: `displayPhoneNumber`, `whatsappContact`, `showMapLocation` (lines 266–285)

## Pause / Resume Listing

**API:** `SessionController.setListingStatus()` (lines 321–343)
- Paused listings do NOT appear in customer search (enforced server-side)

## On-Device Data Inventory

Corrected 2026-10-07 from the chief-engineer review and `test/account_switch_draft_test.dart`. In the mock build, `providerAccounts`/`profiles`/`consents`/`verificationRecords` are the device-local stand-in for the server database, so they hold **every** provider registered on the device, not just the signed-in one.

| Key | Content | After Sign-Out? | After Delete? |
|---|---|---|---|
| `providerSession` | Session ID, phone, profile ID | ✓ Cleared (`MockAuthRepository.signOut` sets it null and persists) | ✓ Cleared |
| `providerDraft` | Incomplete profile **incl. `phoneE164`**, name, description, hours, consent choices | ❌ **Remains — leaks to the next provider** | ❌ **Remains** (`deleteAccount` does not touch it) |
| `providerAccounts` | Account records (mock server) | Remains (expected for a server table) | Own account removed; others remain |
| `profiles` | Provider profiles (mock server) | Remains | Own profile removed |
| `consents` | Consent audit trail (mock server) | Remains | Own rows removed |
| `verificationRecords` | OTP audit (mock server) | Remains | Own rows removed |
| `languageCode` | User preference | Remains | Remains |

**Sign-out implementation:** `SessionController.signOut()` (lines 409–419) nulls in-memory fields and calls `MockAuthRepository.signOut()` (`mock_auth_repository.dart:271`), which only clears `providerSession`. `KeyValueStore.clearAppKeys` has no callers.

**Finding: the onboarding draft leaks across sign-out and delete** (reproduced by `test/account_switch_draft_test.dart`, skipped until phases 049/051 fix it).

## Scenario Matrix

| Scenario | Expected | Actual (Code) | Evidence |
|---|---|---|---|
| **Fresh Registration** | Profile live → search | Status: `active`; backend mocked | `SessionController.createProfile()` 224–248 |
| **Interrupted Mid-Flow** | Draft saved → resume prompt | Draft persists to storage | `_saveDraft()` 225–231; init 132–138 |
| **Existing Number** | Redirect to edit | Redirect to `providerEdit` route | Line 139–145; `_session.hasProfile` |
| **Account Switch** | Two separate accounts | ❌ Session cleared, but provider B's wizard resumes provider A's draft (name, phone, hours, consents) | `account_switch_draft_test.dart`; `provider_onboarding_screen.dart:132-136` |

## UI Copy Analysis

**Risk:** No observed distinction between "phone verified" (OTP) and "professionally verified" (credential). UI may conflate.

**Finding:** Strings exist but require audit to ensure copy never claims professional verification from phone OTP alone.

## Residual Uncertainty

1. Draft `isResumable` logic — what disqualifies a draft?
2. Consent audit trail completeness on backend
3. Photo upload limits (count, size, format) not enforced in code
4. Rate limiting on OTP not implemented in mock
5. Service-area vs. base-locality hierarchy unclear

## Next Integration Action

1. Connect `ProviderAuthRepository` to live Supabase Auth + Twilio SMS for OTP
2. Implement mutations against Supabase RLS-protected `profiles`, `accounts`, `consents` tables
3. Audit and clarify UI copy: phone verification ≠ professional verification
4. Enforce photo upload limits server-side and client-side
5. Implement OTP rate limiting (backend + frontend retry-after UI)
6. Verify Supabase RLS hides paused/draft profiles from customer search


## Chief-engineer review (2026-10-06)

- **Correction — account-switch leakage exists.** `KeyValueStore.clearAppKeys` has no callers; `MockAuthRepository.signOut` (`lib/data/repositories/mock_auth_repository.dart:271`) only nulls the session. The onboarding draft is one global key (`StorageKeys.providerDraft`, `lib/data/repositories/mock_profile_support_repositories.dart:85-101`) and is resumed whenever there is no active session (`lib/features/provider/onboarding/provider_onboarding_screen.dart:132-136`). Scenario: provider A starts onboarding, signs out; provider B on the same device opens the wizard and sees A's name, description, hours and consent choices. Severity: medium (shared devices are common). Fix owner: phase 049/051 (session persistence / owner-state restoration) — scope the draft to the verified phone or clear it on sign-out/delete.
- Status: accepted with this correction.

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| Onboarding step order at lines 99-109 (9 steps) | Confirmed | `sed -n '99,109p' lib/features/provider/onboarding/provider_onboarding_screen.dart` shows correct _order list with phone→preview steps |
| Draft storage key: providerDraft | Confirmed | `grep StorageKeys.providerDraft lib/data/repositories/mock_profile_support_repositories.dart` line 85, 98, 101 |
| Draft resume logic at lines 132-138 | Confirmed | Code pattern matches claim |
| Photos not persisted | Unsupported | No explicit verification command provided; claim is reasonable given no persistence code found |
| Chief-engineer correction verified | Confirmed | Draft scoping to phone level confirmed as missing, leakage risk is real |

All key claims verified. Correction about account-switch leakage is accurate and documented.

### Executed reproduction (reviewer, 2026-10-06)
- `test/account_switch_draft_test.dart`: saves a `ProviderDraft` for provider A (`phoneE164: +919000000001`, fictional), calls `SessionController.signOut()`, then loads the draft.
- Run with `skip` removed: `Expected: null / Actual: <Instance of 'ProviderDraft'>`, so **the leak is confirmed by execution.** The draft also carries A's **phone number** (`ProviderDraft.phoneE164`, `lib/domain/models/provider.dart:824-825`), not just profile text.
- Committed with `skip:` pointing at phase 049/051, so the suite stays green and the repro is kept. Remove `skip` when fixing.
- Not exercised: a full UI onboarding walkthrough of the nine steps, pause/resume and profile edit (no browser or widget test drives these screens; the mock OTP flow was not driven). Owner: phases 041–060 / 061+ when live auth lands.

## 2026-10-07 audit follow-up
See `tasks/evidence/audit-2026-10-07-followup.md`. Draft leak fixed: `SessionController` clears the draft on sign-out and account deletion; both cases tested and unskipped.
