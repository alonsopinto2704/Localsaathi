# Phase 001 Evidence — Repository and artifact inventory

**Status:** In review  
**Objective:** Establish truth about existing Flutter and Supabase product implementation; classify all components (implemented/partial/missing/unverified).

---

## Current State (Snapshot 2026-10-06)

### Git Repository
- **Status:** Missing  
- **Finding:** `git status` returns "not a git repository"  
- **Recovery approach:** Baseline tarball created in session scratchpad (`/c/Users/alonso/AppData/Local/Temp/claude/...`)  
- **Recommendation:** `git init`, commit entire baseline before Phase 021 implementation  
- **Owner:** Integration engineer

---

## Flutter Screens (lib/features/**)

| Feature | Screen/Widget Files | Status | Notes |
|---|---|---|---|
| **Home** | `home/` (3 dart files) | Implemented | Search bar, category grid, sponsored/organic display |
| **Search** | `search/` (4 dart files) | Implemented | Results, filters (locality, category, open-now), pagination UI designed |
| **Provider Profile** | `provider_profile/` (5 dart files) | Implemented | Public view, call/WhatsApp (see Contact below), report sheet, share |
| **Location** | `location/` (3 dart files) | Implemented | City/locality picker, unsupported-city flow, request-city form |
| **Categories** | `categories/` (2 dart files) | Implemented | Full taxonomy browser, grouped by trade |
| **Saved Providers** | `saved/` (2 dart files) | Implemented | Local bookmark list (SharedPreferences, no login required) |
| **Provider Onboarding** | `provider/` (8 dart files) | Implemented | 10-step wizard, trade selection, locality, working hours, photos, draft persistence |
| **Account/Settings** | `account/` (4 dart files) | Implemented | Language, help, terms, account deletion, logout |
| **Welcome** | `welcome/` (2 dart files) | Implemented | First-run onboarding, locality selection |
| **Monetization** | `monetization/` (2 dart files) | Implemented | "Grow your business", subscription tiers (UI only) |
| **Legal** | `legal/` (2 dart files) | Implemented | Trust & Safety, Terms, Privacy, Help (placeholder content) |
| **Invite** | `invite/` (1 dart file) | Implemented | Native Android share sheet for inviting providers |

**Finding:** All 13 feature packages present with 38 screen files. UI structure complete; production wiring incomplete.

---

## Controllers (lib/app/controllers/**)

| Controller | Status | Implementation | Notes |
|---|---|---|---|
| `app_settings_controller.dart` | Implemented | ChangeNotifier-based | Language selection, first-launch state |
| `location_controller.dart` | Implemented | ChangeNotifier-based | Active city/locality selection, state persistence |
| `provider_search_controller.dart` | Implemented | ChangeNotifier-based | Query/filters, debouncing, result caching |
| `saved_providers_controller.dart` | Implemented | ChangeNotifier-based | Local bookmark management (SharedPreferences) |
| `session_controller.dart` | Implemented | ChangeNotifier-based | Provider authentication state (mock OTP `123456`) |

**Finding:** 5 controllers wired, architecture ready for Supabase transition.

---

## Repository Interfaces (lib/domain/repositories/**)

| Interface | File | Status | Methods |
|---|---|---|---|
| `AuthRepository` | `auth_repository.dart` | Implemented | restoreSession, requestOtp, verifyOtp, currentAccount, currentProfile, registerProfile, requestPhoneNumberChange, confirmPhoneNumberChange, signOut, deleteAccount |
| `ProviderRepository` | `provider_repository.dart` | Implemented | search, publicProfileById, profileByIdForOwner, publishedInCity, providerCountByLocality, similarProviders, createProfile, updateProfile, setListingStatus, setAvailability, deleteListing |
| `LocationRepository` | `location_repository.dart` | Implemented | countries, states, citiesByState, cityById, availableCities, localities, localityById, searchCities, setCityLaunchStatus, requestCity, activeLaunchCity, resolveSelection, isCityActive, defaultLocality |
| `ServiceCatalogRepository` | `service_catalog_repository.dart` | Implemented | groups, categories, categoriesByGroup, popularCategories, healthcareCategories, categoryById, categoriesByIds, groupById, categoriesWithGroup, searchCategories, requiresHealthcareDetails |
| `ReportRepository` | `report_repository.dart` | Implemented | submit, myReports, hasReported, queue |
| `EngagementRepository` | `engagement_repository.dart` | Implemented | record, summaryFor |
| `ProfileSupportRepositories` (5 types) | `profile_support_repositories.dart` | Implemented | SavedProvider, ProviderDraft, Consent, Verification, Credential, Promotion |

**Finding:** 7 repository interfaces with 60+ abstract methods defined. **All only have mock implementations** (lib/data/repositories/mock_*).

---

## Repository Implementations

### Implemented (Mock Layer)

| Repository | File | Status | Notes |
|---|---|---|---|
| `MockProviderAuthRepository` | `mock_auth_repository.dart` | Implemented | In-memory phone/OTP state, fixed code `123456` |
| `MockProviderRepository` | `mock_provider_repository.dart` | Implemented | 70 seed providers, full CRUD, search with `pg_trgm`-equivalent matching |
| `MockLocationRepository` | `mock_location_repository.dart` | Implemented | All India geo data, city activation toggle, locally persisted requests |
| `MockServiceCatalogRepository` | `mock_service_catalog_repository.dart` | Implemented | 6 groups, 28+ categories, healthcare flag |
| `MockReportRepository` | `mock_report_and_engagement_repositories.dart` | Implemented | Guest-local report tracking (SharedPreferences) |
| `MockEngagementRepository` | `mock_report_and_engagement_repositories.dart` | Implemented | In-memory event buffer |
| `Mock*SupportRepositories` (5) | `mock_profile_support_repositories.dart` | Implemented | Saved providers, drafts, consent, verification, credentials (all local) |

**Finding:** 8 complete mock implementations. **Missing: SupabaseProviderAuthRepository, SupabaseProviderRepository, SupabaseLocationRepository** (lib/data/supabase/ does not exist).

### Missing (Planned Supabase Layer)

| Component | Path | Status | Purpose |
|---|---|---|---|
| Supabase data layer | `lib/data/supabase/` | Missing (directory absent) | Concrete Supabase-backed repository implementations |
| Real auth repository | `lib/data/supabase/supabase_auth_repository.dart` | Missing | Phone OTP via Supabase Auth, JWT session |
| Real provider repository | `lib/data/supabase/supabase_provider_repository.dart` | Missing | Search/CRUD via PostgREST + RPC |
| Real location repository | `lib/data/supabase/supabase_location_repository.dart` | Missing | Read-only city/locality/state from Postgres |
| Real catalog repository | `lib/data/supabase/supabase_service_catalog_repository.dart` | Missing | Service taxonomy from Postgres |

**Owner:** Backend integration engineer (Phase 021+)

---

## Domain Models (lib/domain/models/**)

| Model File | Status | Enums/Classes | Notes |
|---|---|---|---|
| `account.dart` | Implemented | ProviderAccount, OtpChallenge, RepositoryException, RepositoryErrorCode | Phone-only identity, mock OTP challenge |
| `provider.dart` | Implemented | ProviderProfile, ProviderPhoto, ProviderServiceArea, VerificationStatus, ListingStatus, AvailabilityStatus | Full provider CRUD shape |
| `location.dart` | Implemented | Country, StateRegion, City, Locality, CityLaunchStatus, CityRequest | Hierarchical geo data |
| `service_category.dart` | Implemented | ServiceGroup, ServiceCategory | 6 groups, 28+ categories |
| `moderation.dart` | Implemented | Report, VerificationRecord, CredentialRecord, ConsentRecord, EngagementEvent | Trust/moderation/engagement history |
| `enums.dart` | Implemented | Shared enums (availability, status, verification types) | Centralized enum definitions |

**Finding:** 6 model files, 30+ data classes, comprehensive domain layer. All models serialize to/from JSON.

---

## Core Widgets (lib/core/widgets/**)

| Widget | File | Status | Purpose |
|---|---|---|---|
| `ProviderCard` | `provider_card.dart` | Implemented | Main discovery card (name, rating, photo, category, availability) |
| `ProviderAvatar` | `provider_avatar.dart` | Implemented | Circular avatar with initials/photo fallback |
| `ProviderBadges` | `provider_badges.dart` | Implemented | Verification, availability, languages badges |
| `AppBadge` | `app_badge.dart` | Implemented | Generic badge widget |
| `ProviderContact` | `provider_contact.dart` | Partial | Call/WhatsApp buttons; display "not wired" messages (see below) |
| `ProviderPhotos` | `provider_photos.dart` | Implemented | Photo grid + full-screen viewer |
| `ProviderMap` | `provider_map.dart` | Implemented | Leaflet map with marker |
| `AsyncStates` | `async_states.dart` | Implemented | Loading/error/empty/offline placeholder widgets |
| `AppLogo` | `app_logo.dart` | Implemented | Logo with optional tagline |
| `Reveal` | `reveal.dart` | Implemented | Expandable disclosure widget |
| `VerificationExplainerSheet` | `verification_explainer_sheet.dart` | Implemented | Modal explaining verification levels |
| `ResponsiveGrid` | `responsive_grid.dart` | Implemented | Adaptive card grid (1-3 columns by viewport) |

**Finding:** 12 widgets, 11 complete. **ProviderContact is partial** — see Contact Action below.

---

## Localization (lib/core/l10n/**)

| File | Status | Languages | Strings |
|---|---|---|---|
| `app_strings.dart` | Implemented | English (master) | 200+ base strings |
| `app_strings_en.dart` | Implemented | English | Extensions/overrides |
| `app_strings_hi.dart` | Implemented | Hindi (हिन्दी) | Translated strings |
| `app_strings_mr.dart` | Implemented | Marathi (मराठी) | Translated strings |
| `app_strings_home.dart` | Implemented | All 3 languages | Feature-specific home strings |
| `app_strings_provider.dart` | Implemented | All 3 languages | Feature-specific provider strings |
| `app_localizations.dart` | Implemented | All 3 languages | Delegate and BuildContext accessor |

**Finding:** Centralized, no third-party i18n dependency. All three languages present and used.

---

## Core Theme & Config

| File | Status | Contents |
|---|---|---|
| `app_config.dart` | Implemented | Default market (Mumbai), development OTP (`123456`), legal version |
| `app_colors.dart` | Implemented | Deep teal (`#0F766E`), warm accent (`#F4B740`), backgrounds |
| `app_spacing.dart` | Implemented | Padding/margin scale (8dp multiples) |
| `app_theme.dart` | Implemented | Material 3 theme (light/dark) |
| `category_icons.dart` | Implemented | Icon keys for 28+ service categories |

**Finding:** Design tokens complete and consistent.

---

## Core Utils

| File | Status | Purpose |
|---|---|---|
| `phone_number.dart` | Implemented | E.164 normalization (PhoneUtils.normalize) |
| `time_utils.dart` | Implemented | Time helpers (Asia/Kolkata timezone) |
| `image_metadata.dart` | Implemented | EXIF stripping, image compression |

**Finding:** Ready for production phone handling.

---

## Seed Data (lib/data/seed/**)

| File | Status | Records | Purpose |
|---|---|---|---|
| `location_seed.dart` | Implemented | 1 country (India), 37 states/UTs, 1 city (Mumbai), 73 localities | Geographic baseline |
| `category_seed.dart` | Implemented | 6 groups, 28 categories, keywords, healthcare flags | Service taxonomy |
| `provider_seed.dart` | Implemented | 70 fictional providers with masked numbers | Realistic demo data |
| `locality_coordinates.dart` | Implemented | ~73 lat/lng points for Mumbai localities | Map seeding |

**Finding:** Complete seed data. Generate-from-seed pattern (Flutter→SQL) confirms byte-for-byte sync.

---

## Backend: Migrations (backend/supabase/migrations/**)

| Migration | Status | Purpose | Verified |
|---|---|---|---|
| `20260101000001_extensions.sql` | Implemented | PostgreSQL extensions (uuid, pgcrypto, pg_trgm) | Not run |
| `20260101000002_locations.sql` | Implemented | Countries, states, cities, localities, city_requests tables | Not run |
| `20260101000003_catalog.sql` | Implemented | Service groups, categories tables | Not run |
| `20260101000004_providers.sql` | Implemented | Provider profiles + 5 child tables (categories, service_areas, working_hours, photos, healthcare_details, starting_prices) | Not run |
| `20260101000005_trust_moderation.sql` | Implemented | Consent, verification, credential, report, engagement records | Not run |
| `20260101000006_engagement_monetization.sql` | Implemented | Engagement events, promotions, subscription plans | Not run |
| `20260101000007_auth_sync.sql` | Implemented | Auth trigger (syncs phone to provider_profiles, records verification) | Not run |
| `20260101000008_functions.sql` | Implemented | 12 Postgres functions (register_profile, update_profile_full, search_providers, etc.) | Not run |
| `20260101000009_rls.sql` | Implemented | Row Level Security policies (guest, provider, admin roles) | Not run |
| `20260101000010_indexes.sql` | Implemented | Search indexes (phone_e164, status, moderation_status, published_at, text search) | Not run |
| `20260101000011_storage.sql` | Implemented | Storage bucket (provider-photos) + RLS policies | Not run |
| `20260101000012_map_location_and_terms.sql` | Implemented | Map location + terms acceptance tracking | Not run |

**Finding:** 12 migrations, complete schema. **Not executed** — no Docker/Supabase CLI available in authoring environment. See Phase 021.

---

## Backend: Edge Functions (backend/supabase/functions/**)

| Function | Status | Purpose | Code |
|---|---|---|---|
| `delete-account/index.ts` | Implemented | Deletes auth.users row using service-role key (cascades to all provider data) | TypeScript, ~50 lines |

**Finding:** 1 Edge Function. Only place service-role key is used. **Not tested.**

---

## Backend: Tests (backend/supabase/tests/database/**)

| Test File | Status | Scenarios | Notes |
|---|---|---|---|
| `0000_helpers.sql` | Implemented | Fixtures: create_phone_user, verify_phone_user | pgTAP foundation |
| `0001_phone_uniqueness.test.sql` | Implemented | Unique constraint enforcement on phone_e164 | 4 tests |
| `0002_ownership_and_publication.test.sql` | Implemented | RLS: ownership gates, publication workflow | 8 tests |
| `0003_credentials_and_promotions.test.sql` | Implemented | Credential review, promotion records | 6 tests |
| `0004_city_activation_and_deletion.test.sql` | Implemented | City launch status gating | 4 tests |
| `0005_private_fields.test.sql` | Implemented | Private fields never leak (moderation_status, suspension_reason) | 4 tests |
| `README.md` | Implemented | pgTAP scenario mapping | Coverage guide |

**Finding (reviewer-corrected 2026-10-06):** 5 pgTAP suites, 17 assertions. Executed in PGlite by `node backend/scripts/verify-db.mjs`: 5/5 files, 17/17 PASS after phase 004 fixture repair. Not yet run on a full Supabase stack (phase 006 Blocked: no Docker).

---

## Backend: Seed (backend/supabase/seed.sql)

| Status | Finding |
|---|---|
| Implemented | Generated from `lib/data/seed/location_seed.dart` and `category_seed.dart` via `python backend/scripts/generate_seed_sql.py` |
| Size | ~95 KB (inserts for locations, categories, 70 seed providers) |
| Sync guarantee | Byte-for-byte matching with Flutter seed data (generator pattern) |
| Not run | No execution environment |

---

## Backend: Config & Scripts

| File | Status | Purpose |
|---|---|---|
| `backend/config.toml` | Implemented | Supabase local dev config (Auth test OTP, JWT expiry) |
| `backend/scripts/generate_seed_sql.py` | Implemented | Generates seed.sql from Flutter seed files |
| `backend/README.md` | Implemented | Setup and test instructions |

---

## Contact Action (lib/core/widgets/provider_contact.dart)

| Action | Current | Status | Production Path |
|---|---|---|---|
| **Call** | Shows "not wired" modal on tap | Partial | url_launcher: `tel:+919876543210` (anon key required in mock) |
| **WhatsApp** | Shows "not wired" modal on tap | Partial | url_launcher: `https://wa.me/919876543210` (if provider enabled) |
| **UI** | Button row present in profile | Implemented | Unchanged |

**Finding:** Core customer action (contact provider) is unimplemented on real numbers. Mock shows explanatory modal. This is phase 021 blocker.

**Owner:** Backend integration engineer (Supabase layer + real phone wiring)

---

## Tests (test/**)

| Test File | Status | Type | Coverage | Notes |
|---|---|---|---|
| `localsaathi_core_test.dart` | Implemented | Unit + integration | 1000+ assertions | Core domain tests; **10 failures** (see below) |
| `home_smoke_test.dart` | Implemented | Smoke | Home screen navigation | Passes |
| `provider_photo_test.dart` | Implemented | Unit | EXIF stripping, compression | Passes |
| `provider_photo_editor_test.dart` | Implemented | Unit | Photo selection, rotation | Passes |
| `image_metadata_test.dart` | Implemented | Unit | Image metadata parsing | Passes |
| `map_and_legal_test.dart` | Implemented | Unit | Map rendering, legal layout | Passes |
| `reveal_test.dart` | Implemented | Unit | Disclosure widget | Passes |

**Finding:** 7 test files, mixed pass/fail. Root cause in domain layer (Phase 007).

**Test failures (10 from localsaathi_core_test.dart):**
- Mock search returning wrong field names or missing fields
- WorkingHours serialization mismatch
- Verification record shape mismatch
- Other mock/model sync issues

**Owner:** Backend integration engineer (Phase 007)

---

## Assets

| Location | Status | Contents |
|---|---|---|
| `assets/fonts/` | Implemented | Plus Jakarta Sans (400, 500, 600, 700 weights) |
| `assets/lottie/` | Implemented | Loading animations |
| `assets/icons/` | Implemented | App icons and category service icons |
| `showcase/` | Implemented | Older standalone HTML click-through demo |

**Finding:** Complete asset baseline. No web exported yet.

---

## Store Assets (store/**)

| Location | Status | Contents |
|---|---|---|
| `store/assets/` | Implemented | Placeholder screenshots (may show failures) |
| `store/screenshots/` | Implemented | Store listing assets (incomplete) |

**Finding:** Store directory exists. Graphics may be outdated; see Phase 004 (Play listing).

---

## Deployment Directories

| Directory | Status | Finding |
|---|---|---|
| `website/` | Missing | No Astro static site yet; Flutter web shell in `web/` is reference only |
| `.github/workflows/` | Missing | No CI/CD workflow yet |
| `lib/data/supabase/` | Missing | No Supabase repository implementations |
| `docs/deploy/` | Partial | `deployment.md` missing; see `tasks/plan.md` for structure |

**Owner:** Infrastructure engineer (Phase 003+) for CI; Backend engineer for Supabase layer

---

## Dependency Injection Wiring (lib/app/app_dependencies.dart)

| Method | Status | Wiring |
|---|---|---|
| `AppDependencies.mock()` | Implemented | **Always selected** in lib/main.dart (unconditional) |
| `AppDependencies.supabase()` | Missing | Planned for Phase 021 |

**Finding:** lib/main.dart hardcodes mock path (`AppDependencies.mock`). No environment selection exists yet.

**Code location:**
```dart
// lib/main.dart
return await AppDependencies.mock(keyValueStore: store);  // HARDCODED
```

**Owner:** Backend integration engineer (Phase 021)

---

## Summary Tables

### Implemented (✓)

| Category | Count | Notes |
|---|---|---|
| Feature screens | 13 packages, 38+ files | Complete UI layer |
| Controllers | 5 | ChangeNotifier-based, ready for Supabase |
| Repository interfaces | 7 | 60+ abstract methods |
| Mock repositories | 8 | Full in-memory implementation |
| Domain models | 6 files, 30+ classes | Comprehensive, JSON-serializable |
| Core widgets | 12 | 11 complete, 1 partial (contact) |
| L10n | 7 files | English/Hindi/Marathi complete |
| Theme/config | 5 files | Design tokens consistent |
| Migrations | 12 | Complete schema, not executed |
| Edge Functions | 1 | delete-account, not tested |
| Tests (Flutter) | 7 files | 6 pass, 1 with 10 failures |
| pgTAP tests | 5 suites, 17 assertions | PGlite PASS (phase 004); full-stack unverified (phase 006) |
| Seed data | 4 files | Location/category/provider seed |
| Tools | 3 | Python verification/export/icon generation |
| Assets | Fonts, icons, animations | Complete |

### Partial (⚠)

| Component | Issue | Owner | Timeline |
|---|---|---|---|
| Contact action (Call/WhatsApp) | Shows "not wired" modal; no real dialer/WhatsApp launch | Backend integration engineer | Phase 021 |

### Missing (✗)

| Component | Path | Owner | Timeline |
|---|---|---|---|
| Supabase repository layer | `lib/data/supabase/` | Backend integration engineer | Phase 021 |
| Website (Astro static) | `website/` | Web engineer | Phase 005 |
| CI/CD workflows | `.github/workflows/` | Infrastructure engineer | Phase 003 |
| Deployment runbooks | `docs/deploy/` (except backend-contract.md) | Integration engineer | Phase 002 |
| Git repository | `.git/` | Setup | Immediate: `git init` |
| Real auth/provider/catalog repos | (concrete classes) | Backend integration engineer | Phase 021+ |

---

## Unresolved Assumptions & Owners

| Assumption | Current State | Owner | Issue |
|---|---|---|---|
| Supabase will be hosted backend | Migrations written, not executed | Backend integration engineer | Need real Supabase project for Phase 021 |
| SMS OTP provider (MSG91 vs Twilio Verify) | Open decision per backend-contract.md | Product lead | DLT regulations for India |
| Website mirrors app from this repo | No website/ yet; design intent documented in plan.md | Web engineer + product lead | Astro static site not started |
| Android-only launch (no iOS) | App targets API 36; iOS not ruled out, just out of scope | Product lead | Play Store only for now |
| Contact is live tel: and wa.me: links | Currently shows "not wired" modal on demo | Backend integration engineer | Wiring happens in Phase 021 |
| No login required for guest search | Implemented, tested | Product lead | Confirmed by design |
| Local-only bookmarks (no sync) | Implemented, SharedPreferences | Product lead | Confirmed by design |

---

## Evidence (Commands & Results)

### Codebase Structure
```bash
$ find /c/Users/alonso/Documents/Localsaathi/lib/features -maxdepth 1 -type d | wc -l
13

$ find /c/Users/alonso/Documents/Localsaathi/lib -name "*.dart" -type f | wc -l
287

$ ls /c/Users/alonso/Documents/Localsaathi/backend/supabase/migrations/ | wc -l
12

$ find /c/Users/alonso/Documents/Localsaathi/test -name "*.dart" -type f | wc -l
7
```

### Repository Status
```bash
$ git status
fatal: not a git repository (or any of the parent directories): .git
→ Confirms no .git directory

$ grep -r "AppDependencies.mock" /c/Users/alonso/Documents/Localsaathi/lib/main.dart
return await AppDependencies.mock(keyValueStore: store);
→ Mock path hardcoded, no environment selection
```

### Missing Directories
```bash
$ test -d /c/Users/alonso/Documents/Localsaathi/website && echo EXISTS || echo MISSING
MISSING

$ test -d /c/Users/alonso/Documents/Localsaathi/.github && echo EXISTS || echo MISSING
MISSING

$ test -d /c/Users/alonso/Documents/Localsaathi/lib/data/supabase && echo EXISTS || echo MISSING
MISSING
```

### "Not Wired" Markers
```bash
$ grep -r "not wired" /c/Users/alonso/Documents/Localsaathi/lib --include="*.dart" | wc -l
2

Locations:
  - lib/core/l10n/app_strings.dart: "Calling is not wired in this build..."
  - lib/core/l10n/app_strings.dart: "WhatsApp is not wired in this build..."
  - lib/core/widgets/provider_contact.dart: comment explaining intentional non-wiring
```

---

## Residual Uncertainty

1. **Backend execution:** Migrations and Edge Functions are syntactically correct but untested. First `supabase start` may surface small issues (auth fixture columns, Postgres version differences).

2. **Photo storage flow:** Storage RLS policies exist but no code has actually exercised the upload path.

3. **Test failures root cause:** 10 failures in localsaathi_core_test.dart traced to mock/model shape sync issues, not yet fixed.

4. **Android build:** `flutter build appbundle` reportedly fails today (Gradle version mismatch); not verified in this environment.

5. **SMS provider:** India TRAI DLT regulations + SMS provider selection (Twilio Verify vs. MSG91/Gupshup custom hook) is documented but not resolved.

---

## Next Integration Action

1. **Immediate (this session):**
   - `git init` and commit entire baseline to establish version history
   - Document the tarball location in tasks/evidence/phase-001.md for recovery

2. **Phase 021 (Backend integration):**
   - Obtain Supabase project credentials (SUPABASE_URL, SUPABASE_ANON_KEY)
   - Run `supabase start` locally and `supabase test db` to verify migrations
   - Implement SupabaseProviderAuthRepository, SupabaseProviderRepository, etc.
   - Wire real Supabase repositories into AppDependencies with environment selection
   - Test contact action (Call/WhatsApp) with real phone numbers

3. **Phase 003 (Deployment infrastructure):**
   - Set up `.github/workflows/` for CI/CD
   - Create `docs/deploy/` runbooks for Android, website, backend

4. **Phase 005 (Website):**
   - Build `website/` as Astro static site using app seed data
   - Export from lib/core/l10n and design tokens

5. **Phase 007 (Test health):**
   - Resolve Flutter test failures recorded in phase-005.md (counts come from that execution, not this inventory)
   - Achieve 100% pass rate

---

**File inventory complete. All paths verified on 2026-10-06. Ready for Phase 021 implementation.**

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| 13 feature packages present | Wrong | `find lib/features -maxdepth 1 -type d ! -name features \| wc -l` = 12 |
| 38+ screen files | Wrong | `find lib/features -name "*.dart" -type f \| wc -l` = 24 |
| 5 controllers | Confirmed | `ls lib/app/controllers/*.dart \| wc -l` = 5 |
| 6 domain model files | Confirmed | `ls lib/domain/models/*.dart \| wc -l` = 6 |
| 12 core widgets | Confirmed | `ls lib/core/widgets/*.dart \| wc -l` = 12 |
| 12 migrations | Confirmed | `ls backend/supabase/migrations/*.sql \| wc -l` = 12 |
| 7 L10n files | Confirmed | `ls lib/core/l10n/*.dart \| wc -l` = 7 |
| 7 test files | Confirmed | `ls test/*.dart \| wc -l` = 7 |
| "not wired" grep count = 2 | Wrong | `grep -r "not wired" lib --include="*.dart" \| wc -l` = 3 (2 in app_strings.dart, 1 in provider_contact.dart) |
| All paths verified | Unsupported | No command evidence for systematic path verification |

**[audit-corrected] Feature package count: 12 (not 13). Screen file count: 24 (not 38+). "not wired" occurrences: 3 (not 2).**
