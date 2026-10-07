# Phase 002 Evidence — Customer Journey Baseline

**Status:** In review  
**Objective:** Trace customer journey (locality selection → search → comparison → bookmarks → reporting → contact) and identify broken/mocked actions.  
**Method:** Static code trace of controllers, repositories, l10n, and mock implementations; no device run.

## Journey Matrix

| Step | Screen File | Controller/Repo Interface | Current Implementation | Where It Stops | Expected Production | Responsible Interface |
|---|---|---|---|---|---|---|
| **Locality Selection** | `location_picker_screen.dart` | `LocationController.select()` + `LocationRepository.resolveSelection()` | Mock resolves; persists to `SharedPreferencesStore` key `localsaathi.selected_location` as JSON | None — fully persisted | City/locality picker → result screen | `LocationRepository` |
| **Search Query** | `search_results_screen.dart` | `ProviderSearchController.search()` + `ProviderRepository.search()` | Mock returns `ProviderSearchResults` (sponsored + organic) with sample data | None — mock data only | Query → live results via Supabase | `ProviderRepository` |
| **Comparison** | Provider card in results | Card display logic in `provider_card.dart` | Mock UI displays all fields; working-hours chip, badges, rating | None — rendering works | Side-by-side comparison via cards/profile | Card components |
| **Saving (Bookmarks)** | `saved_providers_screen.dart` | `SavedProvidersController.toggle()` + `SavedProviderRepository.toggle()` | Mock toggles in-memory set; persists to `localsaathi.saved_providers` as JSON string set | None — fully persisted | Add/remove from local bookmarks | `SavedProviderRepository` |
| **Reporting** | `report_listing_sheet.dart` (bottom sheet) | `EngagementRepository.record()` with type `reportListing` | Mock records to `localsaathi.reports` as JSON list | Fire-and-forget; no validation | Submit report → Supabase `reports` table | `EngagementRepository` |
| **Contact — Call** | `provider_contact.dart` | `ProviderContactActions.call()` → URL launcher | Mock shows snackbar: `dialerNotWired` (line 94 of provider_contact.dart) | ❌ Stops at snackbar message | Dial `tel:<phoneE164>` | `url_launcher` package |
| **Contact — WhatsApp** | `provider_contact.dart` | `ProviderContactActions.whatsapp()` → URL launcher | Mock shows snackbar: `whatsappNotWired` (line 111 of provider_contact.dart) | ❌ Stops at snackbar message | Open WhatsApp via `https://wa.me/<phoneE164>` | `url_launcher` package |

## Localization (L10n)

**Key counts:**
- **English (en):** ~479 string getters across `app_strings.dart`, `app_strings_home.dart`, `app_strings_provider.dart` (regex count, reviewer-verified 2026-10-06)
- **Hindi (hi):** 84 `@override`s in `app_strings_hi.dart` (incl. languageCode/languageName) — roughly 80% of strings fall back to English
- **Marathi (mr):** 84 `@override`s in `app_strings_mr.dart` — same ~80% English fallback. **Launch-relevant gap:** hi/mr are starter translations only (file header says so); full translation + native review belongs to Workstream 7 (phases 121–140).

**Critical keys for Phase 002:**
- ✓ `dialerNotWired` (line 234 en) — present in all three
- ✓ `whatsappNotWired` (line 236 en) — present in all three
- ✓ `contactNumberHiddenShort` — present in en, inherited in hi/mr
- ✓ `savedSuccessfully` — present in en, inherited in hi/mr

**Finding:** All required Phase 002 keys exist in English; Hindi/Marathi inherit gracefully on miss. No blocking translation gaps.

## Returning Guest Session — What Persists

Checked `StorageKeys` in `key_value_store.dart` (lines 74–113):

```
selectedLocation         ← Restored on cold start; LocationController.load() applies
languageCode            ← Restored; AppSettingsController sets UI locale
savedProviders          ← List of provider IDs (string set) — persists bookmarks
recentSearches          ← Query history (not yet wired in UI)
```

**On cold start:**
1. `LocationController.load()` (line 43–85 of location_controller.dart) restores `selectedLocation`
2. Falls back to default locality if stored selection no longer resolves
3. `SavedProvidersController.load()` restores `savedProviders` and re-fetches full profiles
4. New search starts with no query; results are empty until user types

**Guest session closure:**
- `KeyValueStore.clearAppKeys()` wipes only `StorageKeys.all` — does NOT touch platform data outside the app's prefix
- On sign-out, only provider-specific keys are cleared: `providerSession`, `providerDraft`, `providerAccounts`, `profiles`, `consents`, `verificationRecords`
- Customer data (`selectedLocation`, `savedProviders`, `languageCode`) **remain after sign-out**

## Broken/Mocked Actions

1. **Call Provider** → `dialerNotWired` snackbar (not wired)
2. **WhatsApp Provider** → `whatsappNotWired` snackbar (not wired)
3. **Live search results** → Mock data only (respects mock data flag in `isSampleData` field of results)

## Code-Level Observations (Not Visually Verified)

- Narrow viewport (mobile): responsive grid `responsive_grid.dart` and Material `SingleChildScrollView` expected to adapt
- Hindi/Marathi rendering: strings defined as getters; no RTL markers, assumes LTR for all three languages
- Demo profiles: masked phone number via `PhoneUtils.mask()` before display (line 37 of provider_contact.dart)

## Residual Uncertainty

1. **Link between customer report and provider:** `openProviderWithReport()` route passes providerId but reason is captured locally in `report_listing_sheet.dart`, not sent to backend
2. **Search result sponsorship:** Mock `ProviderSearchResults.sponsoredProviders` list exists; real routing to sponsored tier unknown
3. **Guest bookmark limit:** No storage quota enforced; local storage growth unbounded

## Next Integration Action

1. Wire `url_launcher` for `tel:` and WhatsApp `wa.me` URIs in `ProviderContactActions`
2. Connect `ProviderRepository.search()` to live Supabase RPC or API endpoint
3. Verify `EngagementRepository.record()` persists reports server-side with timestamp/evidence chain
4. Measure saved bookmarks against device storage limits; consider server-side sync for authenticated customers later

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| English strings: ~479 getters | Confirmed (reviewer override) | `grep -E "^\s+String get " lib/core/l10n/app_strings.dart lib/core/l10n/app_strings_*.dart \| grep -v "@override" \| wc -l` = 630 |
| Hindi overrides: 84 | Confirmed | `grep -c "@override" lib/core/l10n/app_strings_hi.dart` = 84 |
| Marathi overrides: 84 | Confirmed | `grep -c "@override" lib/core/l10n/app_strings_mr.dart` = 84 |
| dialerNotWired key present | Confirmed | `grep -n "dialerNotWired" lib/core/l10n/app_strings.dart` = line 234 |
| whatsappNotWired key present | Confirmed | `grep -n "whatsappNotWired" lib/core/l10n/app_strings.dart` = line 236 |
| Journey tracing via static code | Unsupported | No sample execution or output from actual screen/controller testing |

**[reviewer] Audit claim of 630 rejected:** that grep also matched the hi/mr overrides (`@override` sits on the previous line, so `grep -v` did not exclude them): 466 + 82 + 82 = 630. Base files only: 466 `String get` + 13 parameterised `String x(...)` = **479**.

## Reviewer browser walkthrough (2026-10-06)

Method: `flutter build web --no-pub --release` → served `build/web` (launch config `site`, port 5174) → in-app browser at 375×812 (mobile emulation), localStorage cleared for a fresh guest. Screenshots are kept in the session's tool-results folder (not committed).

| Step | Observed | Verdict |
|---|---|---|
| Fresh guest welcome | Locality picker (Mumbai, Andheri East default) + "Find services". Copy: "Connect directly with **verified** plumbers, electricians…" and "63 providers listed in Mumbai". | **Defect (trust copy):** implies professional verification; only phone is verified. Count comes from mock data. → phase 121–140 copy pass; plan rule "phone verification must never imply professional qualification". |
| Home | Category grid labels truncated at 375 px: "AC repair and servi…", "Home deep cle…". Section header "Verified & active". "Live area" chip shown on sample data; a "Sample data…" banner is present. | Confirms plan's baseline clipping issue; "Verified & active" repeats the trust-copy defect. |
| Search (Plumber) | 1 provider; SPONSORED label + "Promoted by the provider"; "Phone verified" badge (correct wording); demo masked-number notice. | OK (mock). |
| Call | Modal "Demo profile … No real person will be contacted", masked number. | Mocked, as expected. Live contact is phase 061–080. |
| Save bookmark → reload | After a full reload the app restored the last route (`#/search`) and the bookmark stayed filled. | Returning-guest persistence works. |
| Profile | "Details updated 5 Jan 2026", approximate service-area map with "exact address is never shown". | UI is honest; backend still stores the exact pin (phase 012 TH-05). |
| Account tab | Blank for ~2–3 s before rendering on first open. | Minor perf note → phase 121+. |
| Switch to Marathi | **Crash:** 22 console errors (`Another exception was thrown`); the back button and the whole bottom navigation bar rendered as grey error boxes. Most body text stays English (expected partial translation). | **Product defect, fixed in this review** (see below). |

### Fix applied: Hindi/Marathi Material localizations
- Root cause: `lib/app/controllers/app_settings_controller.dart` registered only `DefaultMaterialLocalizations`/`DefaultWidgetsLocalizations`, which support English only, so with `hi` or `mr` selected every widget that needs MaterialLocalizations (BackButton tooltip, NavigationBar) threw.
- Change: added the SDK package `flutter_localizations` (pubspec.yaml; lockfile gains only that entry, no version changes) and replaced the two default delegates with `...GlobalMaterialLocalizations.delegates`.
- Regression test: `test/localization_delegates_test.dart`. Before the fix: `-2` (hi, mr: "MaterialLocalizations has no delegate"). After: passes.
- Full suite: `flutter test --no-pub` → **+61 −10** (was +58 −10; the same 10 pre-existing failures). `flutter analyze` → 71 issues (unchanged).
- Browser re-check after rebuild: Marathi home/categories/account render with Marathi nav labels (मुख्यपृष्ठ, श्रेणी, जतन केलेले, खाते); console errors while navigating = **0** (counted with a `console.error` hook).
- Rollback: revert those two files and delete the test.

### Not exercised in the browser (honest list)
Reporting flow, comparison, Hindi specifically (same root cause and fix as Marathi; covered by the unit test), large-text/accessibility scaling.
