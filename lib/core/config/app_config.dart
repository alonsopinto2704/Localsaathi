/// Central, compile-time configuration for LocalSaathi.
///
/// Nothing user-visible should be hardcoded in screens. Copy, theme and
/// location data all flow from here or from the location repository so that
/// adding a new city never requires touching screen code.
library;

class AppConfig {
  const AppConfig._();

  /// Working product name. Kept configurable in one place so a rename or a
  /// white-label build does not require a find-and-replace across the app.
  static const String appName = 'LocalSaathi';

  /// Short tagline used on the welcome screen.
  static const String tagline = 'Find trusted help near you';

  /// Shown in the account screen. Keep in step with `pubspec.yaml`.
  static const String appVersion = '0.1.0';

  /// Public Play Store / web link used by the share sheet and invitations.
  /// Replace with the real listing URL before the first production release.
  static const String shareBaseUrl = 'https://localsaathi.example/app';

  /// The market a fresh install opens on. This is *seed* data only: the active
  /// market is resolved at runtime from the location repository, so activating
  /// another city never requires a code change.
  static const String defaultCityId = 'mh-mumbai';
  static const String defaultLocalityId = 'mh-mumbai-andheri-west';

  /// Development-only OTP simulation.
  ///
  /// PRODUCTION REPLACEMENT REQUIRED: see README "Before production". The OTP
  /// must be generated and verified by a backend (e.g. Firebase Auth phone
  /// verification, MSG91, or Gupshup) with rate limiting, attempt limits and
  /// replay protection. Nothing in this file is safe for production use.
  static const bool useDevelopmentOtpSimulation = true;

  /// Fixed code accepted by the simulated OTP service.
  static const String developmentOtpCode = '123456';

  /// How long a simulated challenge stays valid.
  static const Duration developmentOtpValidity = Duration(minutes: 5);

  /// Maximum wrong-code attempts before a challenge is discarded.
  static const int developmentOtpMaxAttempts = 5;

  /// Default country dialling code for the launch market. Kept as data so
  /// other countries can be added later without rewriting the phone utilities.
  static const String defaultDialCode = '+91';

  /// Maximum portfolio photos a free listing may publish. The optional
  /// business subscription raises this (see `SubscriptionPlan`).
  static const int freePhotoLimit = 5;

  /// Indicates whether engagement statistics shown to providers are sample
  /// data. While true the dashboard labels every number as sample data.
  static const bool engagementStatsAreSampleData = true;

  static const String supportEmail = 'support@localsaathi.example';

  // ---------------------------------------------------------------- legal
  // The in-app Privacy Policy, Terms, Community Guidelines and Grievance page
  // are built from these values (lib/features/legal). Everything in square
  // brackets MUST be replaced with real details before launch: the IT
  // (Intermediary Guidelines) Rules 2021 require the Grievance Officer's name
  // and contact to be published, and the DPDP Act 2023 requires the data
  // fiduciary to be identifiable.

  /// Set to true only after a lawyer has reviewed the legal text. While false,
  /// every legal page carries a visible "draft" banner.
  static const bool legalTextReviewed = false;

  /// Bump when the Terms or Privacy Policy change materially. Recorded with
  /// each provider's acceptance so we know which wording they agreed to.
  static const String legalVersion = '2026-10-04';
  static const String legalEffectiveDate = '4 October 2026';

  static const String operatorLegalName = '[Registered business name]';
  static const String operatorAddress =
      '[Registered office address], Mumbai, Maharashtra, India';
  static const String grievanceOfficerName = '[Grievance Officer name]';
  static const String grievanceOfficerEmail = 'grievance@localsaathi.example';
  static const String privacyEmail = 'privacy@localsaathi.example';

  /// Courts with jurisdiction under the Terms.
  static const String jurisdictionCity = 'Mumbai';

  /// Copy shown to users whose city is not active yet.
  static const String launchAvailabilityMessage =
      "We're starting in Mumbai. More cities are coming soon.";
}
