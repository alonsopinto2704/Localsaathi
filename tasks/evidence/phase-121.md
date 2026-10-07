# Phase 121 Evidence — Screen, component state, hardcoded string & accessibility matrix

**Status:** Done (read-only audit; no UI files were edited in this phase)

## Objective

Inspect every `.dart` file under `lib/features/` and `lib/core/widgets/` (24 + 12 = 36 files) and produce a file-and-line-linked matrix of how each screen handles `loading`, `empty`, `success`, `error`, `offline`, `disabled / feature-flagged` and `permission denied`; a hardcoded-string and untranslated-copy audit so Phase 129 has a complete checklist; a touch-target/text-scaling/TalkBack audit; and a duplicated-component inventory with a consolidation plan for Phases 122–140.

## Method and evidence

Every file was read in full in this session. Line numbers below come from `grep -n` anchors run on 2026-10-07 over the audited tree. Findings marked **Flag** are defects or gaps a later phase must fix; "Note" items are deliberate decisions that only need their documentation kept.

Shared state widgets live in `lib/core/widgets/async_states.dart`: `AppLoadingState` (labelled spinner), `AppErrorState` (retry), `AppEmptyState` (action), `AppBanner` (info/caution/success/warning + `.development`/`.sampleData`). **There is no offline state and no feature-flagged/disabled-state widget anywhere in the app** — every "offline" cell below is therefore a gap by construction.

## 1. Screen & widget state matrix (`lib/features/`)

Legend: ✓ = handled, ✗ = missing, 🍿 = mocked with a snackbar, 🔇 = silently ignored, ⚑ = feature-flagged/disabled by design.

| Screen / sheet (file) | loading | empty | success | error | offline | flagged / disabled | permission denied | Verdict |
|---|---|---|---|---|---|---|---|---|
| **Home** `home/home_screen.dart` | ✓ `AppLoadingState` (FutureBuilder waiting, ~L108–110) | ✓ `AppEmptyState` + change-location action (~L222–231) | n/a (feed) | ✓ `AppErrorState` + retry (~L110–115); 🍿 locality change is silent-fail-tolerant | ✗ | sample-data banner `AppBanner.sampleData` (~L165) | n/a | Good; offline missing |
| **Shell** `home/home_shell.dart` | n/a | n/a | n/a | n/a | ✗ | — | n/a | Container; nothing to handle |
| **Search results** `search/search_results_screen.dart` | ✓ `controller.isLoading` → `AppLoadingState` (~L340) | ✓ `AppEmptyState`, filters-aware copy + clear action (~L348–357) | ✓ result count header (~L370–385) | ✓ `AppErrorState` + retry (~L343–347) | ✗ | map/list toggle (~L258–260) | n/a | Good; offline missing |
| **Filter sheet** `search/search_filter_sheet.dart` | ✓ spinner (~L120) | n/a | ✓ pops with `SearchFilterResult` | **Flag: ✗** — `_load()` (~L96–110) has no try/catch; an exception leaves the spinner forever | ✗ | — | n/a | Needs error state |
| **Provider profile** `provider_profile/provider_profile_screen.dart` | ✓ `AppLoadingState` (~L105) | ✓ hidden listing → `AppEmptyState` `profileUnavailable` (~L125–135) | n/a | ✓ `AppErrorState` + retry (~L115–120); 🔇 engagement record is deliberately swallowed (~L85–89, comment) | ✗ | healthcare section renders only when `healthcareDetails` present (~L560) | n/a | Good |
| **Report sheet** `provider_profile/report_listing_sheet.dart` | ✓ in-button spinner (~L130) | n/a | ✓ snackbar + pop (~L60–65) | **Flag: ✗** — `reports.submit` (~L52) has no try/catch; failure crashes the sheet | ✗ | — | n/a | Needs submit error handling |
| **Dashboard** `provider/provider_dashboard_screen.dart` | ✓ `_loadingSummary` → `AppLoadingState(compact)` (~L200) | ✓ signed-out → `AppEmptyState` (~L60–70) | ✓ status card + snackbar on pause/resume | 🍿 pause/resume/delete failures → `somethingWentWrong` snackbar only (~L75–100, ~L250–262); 🔇 `_loadSummary` has no error branch (~L44–57) | ✗ | delete gated behind confirm dialog (~L265–290) | n/a | Snackbar-only error handling |
| **Working hours** `provider/working_hours_screen.dart` | n/a (pure editor) | n/a | ✓ pops `WorkingHours` | n/a | ✗ | — | n/a | OK |
| **Onboarding wizard** `provider/onboarding/provider_onboarding_screen.dart` | ✓ `_loadingDraft` → `AppLoadingState` (~L530–531) | n/a | ✓ published snackbar + dashboard route (~L520) | 🍿 all auth/publish errors via `_showError` snackbar (~L310–330); 🔇 `_saveDraft` failure swallowed (~L255–261, comment) | ✗ | ⚑ publish disabled until `_phoneConsent` (~L365–370); WhatsApp switch disabled without it (~L700); back-past-verification blocked (`_back`, ~L345–352) | not-active city dialog (~L770–790) | Solid consent gating; snackbar-only errors |
| **Phone panel** `provider/onboarding/onboarding_widgets.dart` | ✓ busy spinners in buttons (`_ButtonSpinner`, ~L300) | n/a | ✓ `verifiedExisting` phase + banner (~L265–285) | errors surface via parent snackbar; 🔇 none internal | ✗ | ⚑ resend disabled while counting down, `Semantics`-wrapped (~L225–245) | n/a | Good; no SMS permission requested by design |
| **Hours step** `provider/onboarding/onboarding_hours_step.dart` | n/a | n/a | ✓ | ✓ invalid range flagged in `_validateCurrentStep` (onboarding ~L355) | n/a | remove-window disabled on last window (~L100–110) | n/a | OK |
| **Profile editor** `provider/provider_profile_editor_screen.dart` | **Flag: ✗** — `_load()` (~L108) has no loading state; first frame shows a blank form | ✓ signed-out → `AppEmptyState` (~L260–270) | ✓ save snackbar (~L210) | 🍿 validation + save failures → snackbar (`_warn`, ~L216) | ✗ | ⚑ withdrawing phone consent blocks save with explanation (~L190–200); map pin required when map on (~L185) | n/a | Needs a loading state |
| **Location picker** `location/location_picker_screen.dart` | ✓ `AppLoadingState` (~L190) | ✓ search-no-match → `AppEmptyState` (~L205–212, reuses `errorNotFound` as title — Note: copy misuse) | ✓ selection snackbar + pop (~L82–90) | **Flag: ✗** — `_load`/`_search` (~L48–78) have no error handling | ✗ | ⚑ coming-soon cities gated by `launchStatus` (~L115–155) | n/a | Needs error state |
| **City/locality sheets** `location/location_sheets.dart` | ✓ spinners in all three sheets (~L120, ~L280, ~L420) | ✓ `noLocalitiesAvailable` in `_LocalitySheet` (~L295); **Flag: ✗** `_LocalityMultiSheet` shows a blank list when the city has none (~L420–460) | ✓ pop with result | 🍿 `_CitySheet` renders `somethingWentWrong` as plain `Text` (~L185–192) — not `AppErrorState`, no retry | ✗ | — | n/a | Mixed |
| **Request city** `location/request_city_screen.dart` | ✓ in-button spinner (~L120) | n/a | ✓ success banner + snackbar (~L80–90) | **Flag: ✗** — `controller.requestCity` (~L60) not wrapped; only the three enum outcomes are handled | ✗ | ⚑ mock submission banner (`requestCityMockNotice`, ~L125) | n/a | Needs error handling |
| **Account** `account/account_screen.dart` | n/a | n/a | ✓ snackbar confirmations | 🍿 delete-account failure not surfaced (await without check, ~L300) | ✗ | delete only when signed in (~L285) | n/a | Minor |
| **Language** `account/language_screen.dart` | n/a | n/a | ✓ immediate selection | n/a | ✗ | ⚑ partial-translation notice on non-English rows (~L70) | n/a | OK |
| **Categories tab** `categories/categories_screen.dart` | ✓ compact loader on first load (~L180) | ✓ `AppEmptyState` (~L185–190) | ✓ live counts | ✓ `AppErrorState` + retry (~L150) | ✗ | — | n/a | Good |
| **Saved** `saved/saved_providers_screen.dart` | ✓ `saved.isLoading` (~L105) | ✓ `AppEmptyState` (~L110–118); Note: action pops — inside the shell tab that is a no-op | ✓ refreshed on entry (~L38–43) | **Flag: ✗** — no error state; refresh failures silent | ✗ | — | n/a | Needs error state |
| **Welcome** `welcome/welcome_screen.dart` | ✓ `location.isLoading` spinner (~L135) | n/a | ✓ navigation on success | 🍿 `select()` failure → snackbar (~L115–120); 🔇 `_loadLocalities` failures silent (~L60–80) | ✗ | ⚑ non-active city dialog (~L400–445) | n/a | OK |
| **Grow business** `monetization/grow_business_screen.dart` | **Flag: ✗** — `_load()` (~L44) has no loading state; plans pop in late | n/a | ✓ interest snackbar (~L75) | **Flag: ✗** — `registerInterest` (~L60–75) and `_load` have no try/catch | ✗ | ⚑ `pricingComingSoon` everywhere; no prices shown by design (~L100, ~L225) | n/a | Needs both states |
| **Invite** `invite/invite_provider_screen.dart` | n/a | n/a | n/a (OS share sheet) | **Flag (minor): ✗** — `SharePlus.instance.share` (~L25) not wrapped | ✗ | — | n/a | Minor |
| **Legal reader** `legal/legal_screen.dart` | n/a | n/a | n/a | n/a | ✗ | ⚑ draft-legal banner gated by `AppConfig.legalTextReviewed` (~L25) | n/a | OK |

**Cross-cutting flags:** (1) no screen has an offline state — the shared `AppErrorState` icon defaults to `cloud_off` but nothing checks connectivity; (2) sheets (`search_filter_sheet`, `report_listing_sheet`, `monetization`, `saved`) fire repository futures without try/catch; (3) three screens have no loading state at all (editor, grow-business, and the multi-locality sheet's empty case); (4) error-as-snackbar is the only failure surface on dashboard/onboarding/editor/welcome — no retry affordance outside the FutureBuilder screens.

## 2. Hardcoded string & untranslated copy audit

### 2a. Inline user-visible strings that bypass `AppStrings`

| # | Location (file:line) | Literal | Why it matters / disposition |
|---|---|---|---|
| H1 | `location/location_sheets.dart:209` | `'Metro city'` | **Flag — real bypass.** Shown as a city-row subtitle in `_CitySheet._stateNameFor`; not in `AppStrings`, untranslated in hi/mr. |
| H2 | `provider/onboarding/provider_onboarding_screen.dart:756` | `groupId.replaceAll('-', ' ')` | **Flag — highest-impact bypass.** The category step's section headers render raw group ids ("home repairs", "daily workers") instead of the localized `ServiceGroup.name` the rest of the app shows. Same bug at `provider/provider_profile_editor_screen.dart:369`. |
| H3 | `core/widgets/provider_contact.dart:120` | `categoryIds.first.replaceAll('-', ' ')` | Share-sheet body text built from a category id, not its localized name. |
| H4 | `core/widgets/provider_contact.dart:297,331` | `'24 h'`, `'Mon'`…`'Sun'` | `formatWorkingHoursSummary` hardcodes English day abbreviations and the 24-hour literal, bypassing `weekdayName(context, …)`/`TimeUtils` that the profile screen already uses. Rendered in dashboard subtitles and similar-provider rows. |
| H5 | `provider/onboarding/onboarding_widgets.dart:181` | `'am' / 'pm'` | `_TimeField._format` hardcodes 12-hour suffixes; the pickers are forced 12-hour too (`alwaysUse24HourFormat: false`, ~L96). |
| H6 | `core/widgets/provider_map.dart:30` | `'OpenStreetMap contributors'` | Attribution text — licence-mandated, keep English but document (Note). URLs at `provider_map.dart:19–20` are data, not copy. |
| H7 | `core/widgets/app_logo.dart:19,118` | `'LocalSaathi'`, `'Local'`/`'Saathi'` | Brand name + wordmark; keep as-is (brand is not translated), Note. |
| H8 | `onboarding/provider_onboarding_screen.dart:~700` and `provider/provider_profile_editor_screen.dart:57–71` | `['Hindi','Marathi','English',…]` (13 languages, duplicated twice) | Language names are proper nouns (acceptable), but the list is **duplicated** — see inventory D2. |
| H9 | `onboarding/provider_onboarding_screen.dart:~770` | `'${strings.stepLabel} ${_order.indexOf(_step)} ${strings.stepOf} ${_order.length - 1}'` | Not a literal bypass, but English word order is baked into the composition — Devanagari renders ungrammatically. Flag for Phase 129 (parameterized `stepXOfY`). |

Everything else user-visible in the audited files goes through `context.strings` (verified by reading every screen; e.g. all dialogs, snackbars, chips, filters, legal reader chrome).

### 2b. Untranslated `AppStrings` getters (Phase 129 checklist)

Measured mechanically (`grep -oE 'String get [A-Za-z0-9_]+'` per file, set difference, 2026-10-07):

| File | Getters defined |
|---|---|
| `app_strings.dart` (master) | 376 |
| `app_strings_home.dart` | 69 |
| `app_strings_provider.dart` | 28 |
| **Master union** | **473 unique getters** |
| `app_strings_hi.dart` overrides | 89 → **384 untranslated** (81.2%) |
| `app_strings_mr.dart` overrides | 89 → **384 untranslated** (81.2%) |
| `app_strings_en.dart` overrides | 0 (master strings are the English values) |

Untranslated getters fall back to the English text by design (documented in `pubspec.yaml`), so the app is usable but shows English copy under hi/mr. The complete 384-name list per language is identical (hi and mr override the same 89 getters) and is reproduced verbatim for Phase 129:

```
aboutApp aboutBody acceptTermsRequired acceptTermsTitle accountFooterNote activeCity activeMarkets
add addHoursWindow addMoreServicesHint addPhoto all allCategoriesTitle apply appName areYouProBody
areYouProTitle availabilityAvailable availabilityBusy availabilityLabel availabilityUnavailable
availabilityUpdated avatarInitialsHint baseCityLabel baseLocality baseLocalityLabel
browseActiveCityAnyway browseNoSignIn browseProviders businessLocationTitle businessNameHelper
businessNameHint businessNameLabel callButtonTaps cantFindRegularBody cantFindRegularTitle
cantFindWorkerBody cantFindWorkerTitle categoryPickerTitle changeNumber changeNumberHint chargesTitle
chooseLocationToStart chooseYourArea cityNotActiveYet claimsCredentialsLabel clearFilters
clinicAddressHelper clinicAddressLabel clinicNameLabel close closedAllDay closingTimeLabel
commissionNotTrackedNote communityGuidelinesTitle consentShowPhoneBody consentShowPhoneHelp
consentShowPhoneRequired consentShowPhoneTitle consentWhatsappBody consentWhatsappHelp
consentWhatsappTitle consultationHoursLabel contactNumberHidden contactNumberHiddenShort
contactPreferencesTitle copyHoursToAllDays createFreeListing credentials credentialsReviewPending
credentialsVerifiedExplainer dashboardEngagementNote dayFriday dayMonday daySaturday daySunday
dayThursday dayTuesday dayWednesday delete deleteAccount deleteAccountConfirmBody
deleteAccountConfirmTitle deleteAccountDone deleteListingBody deleteListingConfirm deleteListingTitle
demoProfileNotice demoProfileNoticeTitle descriptionHint descriptionLabel developmentOtpNotice
dialerNotWired directDiscovery discardDraft discardDraftConfirm doesNotServeYourArea done
draftDiscarded draftRestored draftSaved duplicateNumberTitle edit effectiveLabel engagementExplainer
enterOtpBody enterOtpTitle errorNetwork errorNotFound errorUnknown exitOnboarding fieldRequired
findServices getDirections grievanceRedressal guestExplainer guestLabel healthcareCredentialsNotice
healthcareDirectoryOnlyNotice healthcareSectionBody healthcareSectionTitle healthcareSpecialtyHint
helpAndSupportBody homeBasedPrivacyBody homeBasedPrivacyTitle homeVisits homeVisitsToggleBody
homeVisitsToggleTitle hoursIndicatorNote indicativeRate invalidPhoneNumber invalidTimeRange invite
inviteBenefitCalls inviteBenefitControl inviteBenefitProfile inviteBody inviteConsentNote
inviteFreeNote inviteMessage inviteMessagePreviewTitle inviteOpenShareSheet inviteTitle
inviteWhatTheyGetTitle knowHelperBody knowHelperTitle languagePickerNote languagePreferenceSubtitle
languagesLabel learnMoreShortLabel legalAgreementLine legalDraftNotice legalSectionTitle
listingDeleted listingPaused listingPausedExplainer listingResumed liveArea localityAndCityContext
localityMustBeInCity localityOnlyPrivacyNote locationTitle mapDataCredit mapPinNeeded
mapSharedByProvider medicalDisclaimer monetizationDisclaimer monetizationSubtitle monetizationTitle
no noCategoriesMatch noDistanceDisclaimer noHomeVisits noLocalitiesAvailable noProvidersForFilters
noProvidersInAreaBody noProvidersInAreaTitle notNow notSet notVerifiedLabel noVerificationForSale
offerServiceBody offerServicesCta offerServiceTitle onboardingIntroCategories
onboardingIntroContact onboardingIntroDetails onboardingIntroHours onboardingIntroLocation
onboardingIntroName onboardingIntroPhotos onboardingIntroPreview oneNumberOneProfile
oneNumberOneProfileStrong openAllDay openingHoursUnknown openingHoursUnknownShort openingTimeLabel
openNowFilterNote openProviderDashboard openSourceLicences orLabel otpAttemptsExceeded otpExpired
otpInvalid otpResent otpSentTo partialTranslationNotice phoneNumberHint phoneVerifiedExplainer
phoneVerifiedNotCredentials photoFormatUnsupported photoFromCamera photoFromGallery photoHelp
photoLimitReached photoPickFailed photosOptionalBody photosOptionalTitle photosUnavailableNotice
pinCodeLabel planCompleteTitle planInsightsTitle planVisibilityTitle popularChoiceLabel popularInArea
previewBody previewProfile previewProfileNotice previewTitle professionalRegistrationLabel
profileNotFound profilePhotoOf profileUnavailable profileUnavailableBody profileViews
promotedByProvider providerAuthBody providerAuthTitle providerDetails providerOnboardingTitle
providerRulesTitle providerSignInSubtitle providerSpaceBody providerSpaceTitle publishedListingHelp
publishedSuccessfully qualificationLabel recentSearches recentWork registeredInterestLabel
registerInterest registerInterestDone registrationClaimedLabel registrationCouncilLabel
registrationNotProvided registrationNumberLabel remove removedFromSaved removeFromSaved removePhoto
reportAProblem reportChooseReason reportDetailsHint reportNoteForCustomers reportReasonClosed
reportReasonOther reportReasonSpam reportReasonWrongDetails reportReasonWrongNumber reportSubmitted
reportTitle requestCityMockNotice requestMyCityAlreadyRequested requestMyCityBody requestMyCityHint
requestMyCitySubmitted requiredLabel reset resultsCount retry sampleDataLabel sampleStatsNotice
saveAndExit saveChanges savedConfirmation savedEmptyBody savedExplainer searchByServiceNameArea
searchCityHint searchEmptyBody searchEmptyTitle searchResults seeAll seeAllCategoriesHint
seeUpcomingCities selectAtLeastOneCategory selectAtLeastOneServiceArea selectCategoriesBody
selectCategoriesTitle servesLabel serviceAreasBody serviceAreasLabel servingArea servingYourArea
setWorkingHours shareProfileMessage showList showMap showOnMapBody showOnMapToggle
signedInAsProvider signedOut signOut signOutConfirm similarProvidersTitle skip somethingWentWrong
speaksLabel specialtyCareNote specialtyLabel sponsoredDisclosure sponsoredListingBulletOne
sponsoredListingBulletThree sponsoredListingBulletTwo sponsoredListingsBody sponsoredListingsTitle
sponsoredPreviewOrganic sponsoredPreviewTitle sponsoredPreviewYourListing startingFrom
startingFromLabel startingPriceDisclaimer startingPriceHint startingPriceLabel startingPrices
stepCategoriesTitle stepContactTitle stepDetailsTitle stepHoursTitle stepLabel stepLocationTitle
stepNameTitle stepOf stepPhotosTitle stepPreviewTitle subscriptionBody subscriptionDisclaimer
subscriptionFeatureContent subscriptionFeaturePhotos subscriptionFeatureServiceAreas
subscriptionFeatureStats subscriptionTitle tapMapToPlacePin upcomingMarkets updateAvailability
useMyLocation useMyLocationUnavailable verificationCareNote verificationExplainerConsentNote
verificationExplainerTitle verificationTitle verifiedAndActive verifyToSignIn versionLabel
viewProfile welcomeHeadline welcomePointOne welcomePointThree welcomePointTwo welcomeSubhead
welcomeTagline whatDoYouNeed whatsapp whatsappButtonTaps whatsappNeedsPhoneConsent
whatsappNotEnabledNote whatsappNotWired whatsappSeparateConsent whatsappUnavailable workingHoursBody
workingHoursTitle yes zeroCommission
```

(H1–H4 above are the strings that additionally have **no** getter anywhere and must first be added to the master, then translated.)

## 3. Touch-target, text-scaling & TalkBack audit

Baseline: `AppSpacing.minTouchTarget = 48` (`app_spacing.dart:32`) — the app's own declared floor. Measured against 360 dp width and Devanagari at 1.3×–1.5× font scale.

### 3a. Sub-48 dp interactive elements

| # | Location (file:line) | Element | Measured | Notes |
|---|---|---|---|---|
| T1 | `home/home_shell.dart:167` | `_TopNavLink` (wide-screen header tabs) | 40 dp tall | `< 48`; Devanagari labels at 1.5× will also clip a 40 dp box. |
| T2 | `home/home_shell.dart:106` | FilledButton "Create free listing" (wide) | 40 dp tall | same. |
| T3 | `home/home_screen.dart:686` | `_InviteCard` OutlinedButton "Invite" | 40 dp tall | primary action on the invite card. |
| T4 | `search/search_results_screen.dart:252` | filter-chip row `SizedBox(height: 40)` | 40 dp row | `InputChip` (≈32 dp) + `FilledButton` clipped to 40; two violations in one row. Chips have no `Semantics` beyond their label. |
| T5 | `categories/categories_screen.dart:148` | group `ChoiceChip` row `SizedBox(height: 40)` | 40 dp row | same pattern. |
| T6 | `core/widgets/provider_map.dart:355` | map-bottom-sheet "View profile" FilledButton | 40 dp tall | inside a `ListTile` that *is* tappable, so the tap target exists — the button itself is small (Note). |
| T7 | `core/widgets/app_badge.dart:239` and `core/widgets/async_states.dart:313` | `TextButton` with `minimumSize: Size(0, 32)` + `shrinkWrap` | 32 dp | used for `AppBanner` actions and the badge explainer — the two most safety-relevant inline actions (report, verification explainer). |
| T8 | `core/widgets/provider_badges.dart:178–196` | "Learn more" `InkWell` in `VerificationBadgeRow` | ≈28 dp (padding `vertical: 2`) | tiny tap target that opens the trust explainer; no `Semantics` wrapper of its own (text is announced, but the hit area fails the 48 dp rule). |
| T9 | `core/widgets/provider_photos.dart:360–368` | photo-remove `IconButton` (`visualDensity: compact`, `iconSize: 18`) | ≈40 dp | has a tooltip ✓ (`removePhoto`); still below floor. |
| T10 | `features/legal/legal_screen.dart:117–127` | `LegalLinks` footer links (`InkWell`, `vertical: AppSpacing.sm`) | ≈36 dp | legal links are low-risk but same rule. |
| T11 | Material `FilterChip`s throughout (`search_filter_sheet.dart` locality+category wraps, `provider_onboarding_screen.dart` categories/languages, `welcome_screen.dart` quick picks) | ≈32 dp default chip height | below floor; all get a label from their `Text`, so TalkBack reads them, but the touch target is short. |

Passes worth keeping: `SelectableTile` and the language picker enforce `minHeight: AppSpacing.minTouchTarget` (`provider_avatar.dart:168`, `language_screen.dart:62`); the WhatsApp compact button is wrapped in `SizedBox.square(dimension: AppSpacing.minTouchTarget)` with a `Tooltip` (`provider_contact.dart:249–266`); every `IconButton` in app bars has a `tooltip` (verified in `home_shell.dart:99`, `search_results_screen.dart:180`, `provider_dashboard_screen.dart:88`, `provider_profile_screen.dart:212–243`, onboarding/appbar icons, photo viewer close).

### 3b. Text-scaling (1.3×–1.5×) clip risks on a 360 dp screen with Devanagari

| # | Location (file:line) | Risk |
|---|---|---|
| S1 | `search_results_screen.dart:252`, `categories_screen.dart:148` | fixed `height: 40` chip rows — Devanagari chip labels clip at 1.5×. |
| S2 | `provider_profile_screen.dart:914` | `_WorkingHoursTable` day column `SizedBox(width: 110)` — "सोमवार" etc. at 1.5× overflows/wraps badly. |
| S3 | `provider_profile_screen.dart:871` | `_DetailRow` label column `SizedBox(width: 140)` — healthcare labels ("पंजीकरण परिषद्") clip. |
| S4 | `core/widgets/provider_badges.dart` `AppBadgeInline` (dense `labelSmall`, `ellipsis`) | trust labels truncate with `…` — ellipsis on "Credentials verified"-type labels silently drops a trust signal at large scale. |
| S5 | `home/home_screen.dart:684–688` | 40 dp `OutlinedButton` inside `_InviteCard` — Devanagari "सेवा देने वालों को बुलाएँ" clips. |
| S6 | `provider/onboarding/provider_onboarding_screen.dart:~770` | step label composed in English word order (H9) — at any scale it reads wrong in hi/mr. |
| S7 | `core/widgets/provider_contact.dart:297,331` | `'24 h'` and English `Mon…Sun` abbreviations (H4) — an untranslated summary line rendered inside `titleMedium` rows. |

Good practice already present: `_CategoryGrid` scales tile height with `MediaQuery.textScalerOf` (`home_screen.dart:600–604`, documented); `PhoneVerificationPanel` switched from `Row` to `Wrap` for the OTP header at 2× (`onboarding_widgets.dart:~168`, found by the phase 058 test); `Reveal` and the shell respect `MediaQuery.disableAnimationsOf`.

### 3c. TalkBack/semantics gaps

- `Semantics` explicitly provided in only one place: the OTP resend button (`onboarding_widgets.dart:~236`, with `excludeSemantics` + stable label instead of a per-tick announcement) — exemplary; replicate for other dynamic counters.
- `AppLogo` has `Semantics(label: 'LocalSaathi', image: true)` (`app_logo.dart:17–22`) ✓.
- Missing: `CategoryTile`/`CategoryListRow` announce name only (icon well is decorative — acceptable); map pins are `GestureDetector`s with no semantic node (`provider_map.dart:46–54`); the photo viewer page counter (`provider_photos.dart:198–205`) is plain text, not a live region; `InputChip` deletions have no custom announcement; charts-free `_StatTile`s are fine as text.
- `Tooltip` coverage on icon-only buttons: complete (all app-bar icon buttons, photo remove, WhatsApp compact, map/list toggle).

## 4. Duplicated component inventory & consolidation plan (Phases 122–140)

| # | Duplication | Exact locations | Consolidation plan |
|---|---|---|---|
| D1 | City-not-active AlertDialog (icon/title/message/close/request/browse) | `location/location_picker_screen.dart:111–155` (`_showNotActive`) ≡ `welcome/welcome_screen.dart:~398–445` (`_showNotActiveYet`) | Extract `showLaunchAvailabilityDialog(context, city, activeCity)` into `core/widgets/`; both callers pass actions. Phase 122. |
| D2 | Language options const list (13 items) | `onboarding/provider_onboarding_screen.dart:~700` ≡ `provider/provider_profile_editor_screen.dart:57–71` | Move to a shared constant (e.g. `core/utils/languages.dart`) or the catalog. Phase 122. |
| D3 | Group-by-`groupId` + `Wrap` of `FilterChip` builder | `provider_onboarding_screen.dart:_buildCategoriesStep` ≡ `provider_profile_editor_screen.dart:build` (byGroup + Wrap + chips, ~30 lines each) | Extract `CategoryChipSelector(groups, selected, onChanged)`. Phase 122. |
| D4 | `_availabilityLabel` switch | `provider/provider_dashboard_screen.dart:~250` ≡ `provider_profile/provider_profile_screen.dart:788` | Move into `AppStrings` extension or `AvailabilityX.label(context)`. Phase 123. |
| D5 | Button spinner `SizedBox(20×20, CircularProgressIndicator(strokeWidth: 2.4, Colors.white))` | `report_listing_sheet.dart:~130`, `provider_onboarding_screen.dart:~480`, `request_city_screen.dart:~130`, `welcome_screen.dart:~245` (+ `_ButtonSpinner` already exists at `onboarding_widgets.dart:~300`) | Promote `_ButtonSpinner` to `core/widgets/button_spinner.dart`; replace all five. Phase 123. |
| D6 | Two badge systems | `core/widgets/app_badge.dart` (`AppBadge`, context-factory styles) vs `core/widgets/provider_badges.dart` (`AppBadgeInline`, param factories) — same four visual styles | Keep `AppBadgeInline` (used everywhere), delete/re-express `AppBadge` + `VerificationLabels` (only used by each other). Phase 124. |
| D7 | Two section-header patterns | `core/widgets/async_states.dart` `SectionHeader` vs `provider_profile_screen.dart` `_Section` (card-wrapped) | Rename `_Section` → `AppSectionCard` in core; keep `SectionHeader` for bare rows. Phase 124. |
| D8 | Locality-name resolve + cache | `mock_provider_repository.dart` (`_localityNames` + `warmLocalityCache`), `search_results_screen.dart:40–60`, `saved_providers_screen.dart:39–85`, `home_screen.dart:_resolve` | One `LocationNameResolver` on `LocationRepository` (`nameFor(id)`, `warm()`), screens stop caching. Phase 125 (also fixes the cold-cache search quirk the phase-101 suite had to warm around). |
| D9 | Sheet bottom bar (`SafeArea` + padding + primary/secondary buttons) | `search_filter_sheet.dart`, `report_listing_sheet.dart`, `location_sheets.dart` (`_LocalityMultiSheet`), `working_hours_screen.dart`, onboarding bottom bar | `AppSheetFooter(primary:, secondary:)`. Phase 125. |
| D10 | Draggable-scrollable-sheet scaffolding (sizes 0.85–0.95 + header + list) | `search_filter_sheet.dart`, `report_listing_sheet.dart`, 3 sheets in `location_sheets.dart` | `AppSheetScaffold(title:, child:, footer:)`. Phase 125. |
| D11 | `errorNotFound` reused as an empty-state title | `location_picker_screen.dart:~250`, `categories_screen.dart:~215` | Dedicated `noSearchResults`/`noCategoriesFound` getters in Phase 129 (copy fix, not widget work). |
| D12 | Snackbar-only error reporting | `report_listing_sheet.dart`, `provider_dashboard_screen.dart` (`_togglePause`, `_setAvailability`, `_confirmDelete`), `provider_profile_editor_screen.dart:_warn`, `provider_onboarding_screen.dart:_showError` | Introduce `AppMessageController` (snackbar now, banner+retry later) so Phase 14x can swap persistence per surface without touching every screen. Phase 126. |

## Commands and results

Read-only inspection; no UI file was edited. Anchors above were pinned with `grep -n` (all line numbers verified 2026-10-07 against the working tree):

```
grep -n "Metro city" lib/features/location/location_sheets.dart            → 209
grep -rn "replaceAll('-'" lib/features lib/core/widgets                     → onboarding 756, editor 369, contact 120
grep -n "minimumSize: const Size(0, 40)" -r lib/features lib/core/widgets  → home 686, shell 106/167, search 261, map 355
grep -n "height: 40," lib/features/search lib/features/categories -r       → search 252, categories 148
grep -n "minimumSize: const Size(0, 32)" -r lib/core                        → app_badge 239, async_states 313
grep -n "width: 110" / "width: 140" provider_profile_screen.dart            → 914 / 871
grep -rn "minTouchTarget" lib/core/theme/app_spacing.dart                   → 32: minTouchTarget = 48
l10n getter census (grep + comm): master union 473; hi/mr overrides 89; missing 384 each
```

## Security/privacy effect

None directly (inspection only). The report's findings feed Phase 129 (copy) and Phase 122–126 (components); the trust-label truncation (S4) and the 32 dp report/explainer buttons (T7/T8) are the accessibility-relevant trust surfaces worth prioritising.

## Residual risks

- Line numbers shift with any edit to these files; anchors were pinned today and each row cites its enclosing symbol so it survives reformatting.
- Chip/button default metrics come from Material's defaults, not runtime measurement; the 32/40 dp numbers are exact for the `Size(…)`/`SizedBox(height:)` constraints and approximate for default-height widgets.
- Phase 129's translation checklist depends on `AppStrings` not growing faster than translations; the 473/89/89 census is a point-in-time snapshot.

## Rollback procedure

This file is additive evidence only: delete `tasks/evidence/phase-121.md`. No source file was modified, so there is nothing to revert.

## Reviewer

Pending (human sign-off).

## Next action

1. Phase 122: land D1–D3 (shared launch-availability dialog, language constants, `CategoryChipSelector`) and fix H1–H2 (the `'Metro city'` literal and the raw group-id headers — the two real copy bugs).
2. Phase 123–124: D4–D7.
3. Phase 125–126: D8–D12 (the name resolver also unblocks deterministic search tests).
4. Phase 129: translate the 89-getter gap first (it is the smaller, user-visible half), then the 384; add H1–H4 getters to the master in the same pass.

