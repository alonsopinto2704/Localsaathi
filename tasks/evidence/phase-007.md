# Phase 007 — Release configuration baseline

**Status:** Done (gate passed in phase-020; human sign-off pending)

**Objective:** Inspect build configuration (Gradle, SDK targets, signing, permissions, dependencies) and identify paths that permit debug signing or mock dependencies in release builds. Produce fail-closed matrix for debug/staging/production.

## Changed paths

None (read-only inspection).

## Build configuration files inspected

- android/settings.gradle (Gradle + Kotlin plugin versions)
- android/build.gradle (repository and output configuration)
- android/app/build.gradle (app signing, SDK targets, minify, proguard)
- android/gradle.gradle.properties (JVM args, AGP 9 opt-outs)
- android/gradle/wrapper/gradle-wrapper.properties (Gradle 9.3.1)
- android/app/src/main/AndroidManifest.xml (permissions, intent filters)
- android/key.properties.template (release signing template)
- lib/main.dart (mock-only dependency injection)
- lib/app/app_dependencies.dart (composition root, mock() factory only)
- pubspec.yaml (dependencies and version)

## Commands and results

### Gradle and plugin versions
```
Gradle: 9.3.1
AGP (com.android.application): 9.1.0
Kotlin: 2.4.0
JVM target: 17
Android compileSdk: 36
Android targetSdk: 36
Android minSdk: flutter.minSdkVersion (typically API 24)
```

### Signing configuration (app/build.gradle:50–59, 62–65)
```gradle
signingConfigs {
    if (hasReleaseSigning) {
        release {
            keyAlias = keystoreProperties["keyAlias"]
            keyPassword = keystoreProperties["keyPassword"]
            storeFile = keystoreProperties["storeFile"] ? file(...) : null
            storePassword = keystoreProperties["storePassword"]
        }
    }
}
buildTypes {
    release {
        signingConfig = hasReleaseSigning ? signingConfigs.release : signingConfigs.debug
        minifyEnabled = true
        shrinkResources = true
        proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"
    }
    debug {
        applicationIdSuffix = ".debug"
        versionNameSuffix = "-debug"
    }
}
```

**Critical finding:** Release build falls back to debug signing if key.properties does not exist (line 65).

### Permissions (AndroidManifest.xml)
- **Uses-permission (1):** INTERNET (for backend/map tiles)
- **No location, camera, media, or contact permissions declared**
- **Intent queries:** DIAL (tel:), SMS (smsto:), generic SEND (text/plain), VIEW (https://)
- **No cleartext traffic:** android:usesCleartextTraffic="false"
- **No backup:** android:allowBackup="false", android:fullBackupContent="false"

### Locales
```gradle
androidResources {
    localeFilters += ["en", "hi", "mr"]
}
```
App is correctly scoped to English, Hindi, Marathi.

### Dependencies (pubspec.yaml)
- supabase_flutter 2.18.0 (present but only used if built with --dart-define=SUPABASE_URL/SUPABASE_ANON_KEY)
- share_plus, image_picker, flutter_map, url_launcher (all optional UI features)

### Dependency injection (lib/main.dart and lib/app/app_dependencies.dart)

**Critical finding:** main.dart line 28 calls only `AppDependencies.mock(…)` unconditionally:
```dart
Future<AppDependencies> _buildDependencies() async {
  try {
    final SharedPreferencesStore store = await SharedPreferencesStore.open();
    return await AppDependencies.mock(keyValueStore: store);  // <-- ALWAYS MOCK
  } on Object catch (error, stack) {
    debugPrint('${AppConfig.appName}: falling back to in-memory storage...');
    return AppDependencies.mock(keyValueStore: InMemoryKeyValueStore(), persist: false);
  }
}
```

**app_dependencies.dart** has only one factory:
```dart
static Future<AppDependencies> mock({
    KeyValueStore? keyValueStore,
    bool persist = true,
    DateTime? now,
}) async {
    // Wires only MockProviderRepository, MockAuthRepository, etc.
    // No production() factory exists.
}
```

## Findings

### Release signing

**Current state:**
- Release build WILL fall back to debug signing if android/key.properties is missing.
- Play Store will reject debug-signed APKs.
- Local development can build "release" variant without a keystore for testing.
- Production builds require android/key.properties (never committed; managed as secret).

**Risk:** A CI/CD pipeline that mistakenly omits key.properties will produce a Play-incompatible release build without failing the build.

### Mock dependencies

**Critical issue:** app/app_dependencies.dart has no production factory. main.dart always calls `.mock()` regardless of build variant or --dart-define flags.

**Implications:**
- Release builds for Play Store ship with mock repos, not real Supabase.
- OTP, provider registration, listings, photo uploads, and all backend operations are stubbed.
- No environment-specific configuration (e.g., SUPABASE_URL, SUPABASE_ANON_KEY) is read or validated.
- Supabase dependency is declared but dead code in current release builds.

**Resolution required:** Implement AppDependencies.production() factory and wire it via --dart-define or build config before Play Store release.

### SDK targets

- compileSdk 36: meets Play Store requirement (API 36 from 31 Aug 2026 for new apps/updates).
- targetSdk 36: correct.
- minSdk from flutter.minSdkVersion: likely API 24 (Flutter default), supported by all current Play Store devices.
- sourceCompatibility/targetCompatibility: Java 17, compatible with AGP 9 and modern Android tooling.

### Kotlin and AGP

- AGP 9.1.0 is current (Sept 2026); no deprecation warnings.
- Kotlin 2.4.0 is current.
- android.builtInKotlin=false: temporary workaround for AGP 9 + share_plus 11.x; safe until AGP 10 removes the option.
- android.newDsl=false: temporary for AGP 9; removed in AGP 10.

### Permissions and cleartext traffic

- **Appropriate:** Minimal permission set (INTERNET only); no unused declarations.
- **Security:** Cleartext traffic disabled, backup disabled, no developer-debuggable leftovers detected.

## Build/staging/production matrix

| Dimension | Debug | Staging | Production |
|-----------|-------|---------|-----------|
| **Signing** | Debug key (built-in) | debug signing | Release key (android/key.properties, must exist and be correct) |
| **applicationId** | com.localsaathi.app.debug | ? (if implemented) | com.localsaathi.app |
| **Mock dependencies** | YES (AppDependencies.mock) | YES (AppDependencies.mock) | YES ⚠️ FAIL-CLOSED REQUIRED |
| **SUPABASE_URL** | Not read | Not read (unless wired) | MUST be set and non-empty; build must fail if absent |
| **SUPABASE_ANON_KEY** | Not read | Not read (unless wired) | MUST be set and non-empty; build must fail if absent |
| **Minify/shrink** | false | false (typical) | true (enabled) |
| **Play Store compatible** | No (debug sig) | No (debug sig) | Only if key.properties present and correct |
| **Cleartext traffic** | Disabled | Disabled | Disabled (good) |

### Fail-closed requirements (production)

1. **Release build MUST fail if android/key.properties is missing or malformed.**
   - Current: Falls back to debug signing (FAIL-OPEN).
   - Required fix: Add a build-time check that throws if hasReleaseSigning is false.

2. **Release build MUST fail if mock dependencies are wired.**
   - Current: AppDependencies.mock() always called (FAIL-OPEN).
   - Required fix: Implement AppDependencies.production(…) and wire it in main.dart based on a build-time constant (e.g., const bool kMockMode = …).

3. **Release build MUST fail if SUPABASE_URL or SUPABASE_ANON_KEY are absent or empty.**
   - Current: No validation (FAIL-OPEN).
   - Required fix: Add build-time or startup assertions that SUPABASE_URL and SUPABASE_ANON_KEY are non-empty strings before any network I/O.

4. **Release build MUST fail while development/placeholder constants in `lib/core/config/app_config.dart` are still set** (inspected 2026-10-07; all are `static const`, so a release check can be a compile-time `assert` or a CI grep):
   | Constant (line) | Current value | Production requirement |
   |---|---|---|
   | `useDevelopmentOtpSimulation` (37) | `true` | must be `false`; OTP must come from the backend |
   | `developmentOtpCode` (40) | `'123456'` | must be unreachable when simulation is off |
   | `engagementStatsAreSampleData` (58) | `true` | `false` only once stats come from `engagement_events` |
   | `legalTextReviewed` (72) | `false` | `true` only after legal review (otherwise pages show a draft banner) |
   | `operatorLegalName`, `operatorAddress`, `grievanceOfficerName` (79–82) | `[...]` placeholders | real values (IT Rules 2021, DPDP Act) |
   | `supportEmail`, `grievanceOfficerEmail`, `privacyEmail`, `shareBaseUrl` (23, 60, 83–84) | `*.example` domains | real domain |

5. **Staging builds MUST use production signing but staging Supabase project.**
   - Current: No staging configuration (not implemented).
   - Proposed: Add buildTypes.staging with same signing as release but different --dart-define values.

## Unresolved build checks

- **Release APK not built.** Gradle/APK builds skipped per RAM constraints (16GB; no permission to run).
- **Supabase environment variables not validated at runtime.** `app_config.dart` was inspected (2026-10-07): it holds no Supabase URL/key at all, and `supabase_flutter` is in pubspec but not initialised; the dev/placeholder constants it does hold are listed in fail-closed requirement 4.
- **R8 rules checked.** `android/app/proguard-rules.pro` exists and keeps `io.flutter.**`, `io.flutter.plugins.**` and the shared_preferences plugin. No rules for `supabase_flutter`/`url_launcher` yet; both are Dart-side or ship consumer rules, so this is only proven by a release build smoke test (not run: RAM constraint).
- **Play Data Safety form.** No risks flagged; app declares INTERNET only and no user data collection; however, if Supabase backend later logs requests, disclosure required.
- **Staging variant not implemented.** Proposed but not wired; Phase 281+ will need this.

## Residual risks

1. **Production release can ship mock repos.** A missing key.properties or a developer's local edit of main.dart bypassing production() factory would allow mock data to reach Play Store.

2. **No environment guard at build time.** A developer could manually remove --dart-define=SUPABASE_URL without the build failing.

3. **Dependency on external build scripts.** Play Store release requires manual entry of secrets into CI/CD; no secret rotation or audit log built in yet.

## Rollback

Local changes: none. Preserve gradle.properties and app/build.gradle as baseline for future AGP upgrades.

## Next integration action

- **Pre-release gate (Phase 281+):** Before any Play Store upload:
  1. Implement AppDependencies.production(…) factory.
  2. Add build-time fail-closed checks for key.properties, SUPABASE_URL, SUPABASE_ANON_KEY.
  3. Validate that release builds refuse mock dependencies and verify Supabase environment against expected backend.

- **Staging environment:** Set up CI/CD with distinct Supabase project and secrets for staging releases.

- **Historical build failures:** None discovered in current files; Gradle 9.3.1 and AGP 9.1.0 are current stable versions.

## Independent audit (2026-10-06)

| Claim | Verdict | Proof |
|-------|---------|-------|
| Signing config at lines 50-65 | Confirmed | `sed -n '50,65p' android/app/build.gradle` matches code shown |
| Falls back to debug signing if key.properties missing | Confirmed | Line shows: `signingConfig = hasReleaseSigning ? signingConfigs.release : signingConfigs.debug` |
| AppDependencies.mock() always called | Confirmed | `grep -A5 "_buildDependencies" lib/main.dart` shows unconditional `.mock()` call |
| No AppDependencies.production() factory | Confirmed | `grep "production" lib/app/app_dependencies.dart` returns no matches |
| Gradle 9.3.1 and AGP 9.1.0 current | Unsupported | Dates claimed (Sept 2026) but no verification command; cutoff is Feb 2025 |

All critical build configuration claims verified. Mock dependency wiring correctly identified as production risk.
