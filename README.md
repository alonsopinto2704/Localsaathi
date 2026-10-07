# LocalSaathi (लोकल साथी)

> Find and contact trusted local service providers across India.
> Starting with Mumbai as the first active market, with nationwide data-driven expansion.

LocalSaathi is a Flutter Android application designed for everyday people and local service providers across India. It connects customers needing home repairs, domestic services, daily workers, vehicle assistance, healthcare discovery, and digital services with verified local providers.

---

## Key Principles & Design Direction

- **Customer Journey**: Select locality → find service → compare providers → tap Call or WhatsApp.
- **Browse Without Account**: Customers browse, search, and save providers locally without registering.
- **Provider Ownership**: One verified phone number = one provider account = one public profile.
- **Data-Driven Market Expansion**: Mumbai is the first active city, but cities, localities, and categories are pure data configurations — adding a new market requires zero UI rewrites.
- **Light & Accessible UI**: Built to the "Local Utility Trust" design blueprint (Google Stitch export, `stitch_localsaathi_android_ui_ux_blueprint.zip`): deep teal primary (`#0F766E`), one warm accent (`#F4B740`), cool `#F7F9FA` background with white 16px-radius cards, Plus Jakarta Sans (bundled in `assets/fonts`), 48dp touch targets. Two blueprint colours were darkened to pass 4.5:1 contrast (WhatsApp green `#15803D`, verified-badge text). Motion is short and purposeful (content rises in once, pushed screens fade up, tabs fade through) and switches off when the system asks for reduced motion.
- **Website**: The same Flutter app runs in the browser. Above 840px wide it lays out like a website: navigation in the header, a centred content column, two-column provider cards.
- **Centralized Localization**: Interface strings in English, Hindi (हिन्दी), and Marathi (मराठी) without third-party dependencies or build breakage risk.

---

## Project Structure

```
lib/
├── app/
│   ├── controllers/            # ChangeNotifier-based controllers
│   │   ├── app_settings_controller.dart     # Language & first-launch state
│   │   ├── location_controller.dart         # Active city & locality selection
│   │   ├── provider_search_controller.dart  # Search queries, filters & debouncing
│   │   ├── saved_providers_controller.dart  # Locally saved bookmarks
│   │   └── session_controller.dart          # Authenticated provider session
│   ├── app_dependencies.dart   # Dependency injection container for repositories
│   ├── app_routes.dart         # Named route constants and route generator
│   └── local_saathi_app.dart   # MaterialApp with theme and localization delegates
├── core/
│   ├── config/app_config.dart  # Central constants, default market & OTP simulation
│   ├── l10n/                   # Localizations (English master, Hindi, Marathi)
│   ├── theme/                  # AppColors, AppSpacing, AppTheme, CategoryIcons
│   ├── utils/                  # Phone normalization (E.164) & time helpers
│   └── widgets/                # Reusable ProviderCard, Avatar, Badge, AsyncStates
├── data/
│   ├── local/key_value_store.dart       # SharedPreferences & InMemory abstractions
│   ├── repositories/                    # In-memory mock repositories
│   │   ├── mock_auth_repository.dart
│   │   ├── mock_location_repository.dart
│   │   ├── mock_provider_repository.dart
│   │   ├── mock_profile_support_repositories.dart
│   │   └── mock_report_and_engagement_repositories.dart
│   └── seed/                            # Realistic seed datasets
│       ├── category_seed.dart           # 6 groups, 28+ service categories
│       ├── location_seed.dart           # All India states/UTs, cities, Mumbai localities
│       └── provider_seed.dart           # 70 fictional providers with masked numbers
├── domain/
│   ├── models/                 # Immutable domain models (Provider, Account, Location, etc.)
│   └── repositories/           # Abstract repository contracts
└── features/                   # Screen features
    ├── account/                # Settings, language, help, terms, account deletion
    ├── categories/             # Full category catalog browser grouped by trade
    ├── home/                   # Home screen with search bar, popular trades, sponsored & organic
    ├── invite/                 # Invite a provider via native Android share sheet
    ├── location/               # City & locality picker, unsupported city dialog, request city
    ├── monetization/           # "Grow your business", sponsored info & subscription tiers
    ├── provider/               # Onboarding wizard (10 steps), dashboard, profile editor
    ├── provider_profile/       # Public provider details, call/WhatsApp, report sheet
    ├── saved/                  # Locally saved bookmarks (no login required)
    ├── search/                 # Search results with filters (locality, category, open now)
    └── welcome/                # First-run welcome & locality selection
```

---

Outside `lib/`: `web/` is the Flutter web shell. Preview the real app in a browser with `flutter build web` and the `site` launch config (port 5174).

---

## Service Taxonomy (6 Groups & Categories)

1. **Home repairs**: Plumbers, Electricians, Carpenters, Painters, Masons, Welders, AC repair, Appliance repair, Locksmiths & key makers, TV & electronics repair, Tiles & marble, Waterproofing, Interior work.
2. **Home services**: Cleaning, Pest control, Laundry & ironing, Sofa & carpet cleaning, Water tank cleaning.
3. **Daily workers**: General helpers, Construction labourers, Loading & unloading workers, Gardening, Security guards.
4. **Vehicle services**: Two-wheeler mechanics, Car mechanics, Puncture repair, Towing, Drivers.
5. **Healthcare**: General physicians, Dentists, Paediatricians, Physiotherapists, Diagnostic centres, Home nursing, Veterinary.
6. **Other services**: Computer & laptop repair, Network technicians, Tutors, Packers & movers, Mobile repair, Beauty services, Tailoring, Event help.

---

## What Works Locally (Mock Layer)

- **Browse & Filter**: Select any Mumbai locality (Andheri, Bandra, Borivali, Dadar, Kurla, Chembur, Powai, Colaba, etc.) and see providers serving that locality.
- **Search**: Multi-token search matching trade names, provider names, everyday keywords ("pipe", "fridge", "leak", "wifi"), and localities.
- **Save Providers**: Toggle bookmark button on any card or profile; view saved list offline.
- **Provider Photos**: Providers add up to 5 photos of their work from the gallery or camera (onboarding photo step and Edit listing). Images are resized and compressed on the device; customers see them on cards, in a "Recent work" strip and in a full-screen viewer.
- **Provider Onboarding**: 10-step guided onboarding with phone verification (simulated OTP `123456`), trade selection, locality mapping, working hours, and drafts persisted locally.
- **Uniqueness & Ownership**: Entering an already registered number routes to sign-in; duplicate accounts are rejected; users can only edit their own profile.
- **Dashboard & Listing Control**: Providers can pause/resume listings (paused listings vanish from public search instantly), update working hours, and view engagement counters.
- **Unsupported City Flow**: Selecting an upcoming city (e.g. Pune, Thane, Bengaluru) displays *"We're starting in Mumbai. More cities are coming soon"* with options to browse Mumbai anyway or submit a city request.
- **Healthcare Directory**: Doctors and clinics can add qualifications and clinic hours without falsely claiming credentials verification.

---

## What is Mocked in This Build

- **OTP Verification**: Uses `AppConfig.developmentOtpCode` (`123456`). Clearly labeled in UI as development simulation.
- **Phone Calls & WhatsApp**: Tapping Call or WhatsApp on demo profiles shows an explanatory modal dialog explaining the profile is fictional demo data.
- **Photo storage**: Picked photos are kept with the profile on the device. Production uploads them to object storage (the backend's `storage` migration) and stores a URL instead.
- **Engagement Counters**: Dashboard displays sample statistics and explicitly notes button taps are not confirmed jobs or completed transactions.

---

## Requirements Before Production Release (Backend Integration)

1. **SMS OTP Gateway**: Replace simulated OTP with SMS gateway (Firebase Phone Auth, MSG91, Twilio, or Gupshup) with strict rate-limiting and replay protection.
2. **Server-Side Unique Constraint**: Database unique index on `phone_e164` to enforce one-account-per-number.
3. **Storage & CDN**: Cloud bucket (S3 / Cloud Storage / ImageKit) for provider profile photos and portfolio uploads with moderation pre-flight.
4. **Dialer & WhatsApp Launcher**: Wire `url_launcher` with `tel:` and `https://wa.me/` intents for live numbers.
5. **Credential Review Pipeline**: Admin dashboard for reviewing medical council registrations and certifications before granting the `Credentials Verified` badge.

---

## Setup & Run Commands

### Prerequisites
- Flutter SDK (>=3.24.0)
- Dart SDK (>=3.5.0)
- Android Studio / Android SDK (Platform API 35, Build Tools)

### Commands

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run unit & domain integration tests (1000+ assertions)
flutter test

# 3. Launch on connected Android device or emulator
flutter run

# 3b. Run as a website (Chrome), or build the static site into build/web
flutter run -d chrome
flutter build web --release

# 4. Build debug APK
flutter build apk --debug

# 5. Build production release bundle (requires release keystore configured)
flutter build appbundle --release
```

### Offline Verification (Available without Flutter SDK)

```bash
# Run source code integrity checks (syntax, quotes, imports, seed references)
python tool/check_sources.py

# Run comprehensive domain constraint checks
python tool/run_verification.py
```
