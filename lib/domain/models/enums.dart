/// Availability status of a city in the app.
///
/// Only [active] cities can be selected as a browsing market and only active
/// cities accept new provider listings. Activating a city is a data change in
/// `MockLocationRepository` (later: a backend record) — no screen code changes.
enum CityLaunchStatus {
  /// Live market: browse and register providers.
  active,

  /// Visible in the picker so users can see it is planned, but not selectable
  /// as a browsing market. Users may request it.
  comingSoon,

  /// Present in data for completeness/future use, hidden from the picker.
  inactive;

  bool get isSelectable => this == CityLaunchStatus.active;
  bool get isVisibleInPicker => this != CityLaunchStatus.inactive;
}

/// Why a provider is or is not discoverable by customers.
///
/// A listing is only visible when the status is [published]. Pausing keeps the
/// profile and its statistics but removes it from every public surface.
enum ListingStatus {
  draft,
  published,
  paused,
  deleted;

  bool get isPubliclyVisible => this == ListingStatus.published;
}

/// Whether a provider is taking work. This is *not* a real-time indicator and
/// the UI must never imply a provider will respond immediately.
enum AvailabilityStatus {
  available,
  busy,
  unavailable,
}

/// The two independent trust signals. They must never be merged in the UI.
///
/// * [phone] — the provider proved control of the phone number by OTP.
/// * [credentials] — a separate review of professional documents.
///
/// OTP verification says nothing about qualifications, especially in
/// healthcare.
enum VerificationKind {
  phone,
  credentials,
}

/// Outcomes recorded in the verification trail.
enum VerificationStatus {
  notStarted,
  pending,
  approved,
  rejected,
}

/// Explicit, separately-recorded permissions from a provider.
enum ConsentKind {
  /// Publish the contact number. Mandatory before a listing can go live.
  displayPhoneNumber,

  /// Expose a WhatsApp action. Optional and independent of the above.
  whatsappContact,

  /// Accept that profile content is public.
  publicProfile,

  /// Consent to be contacted about the business subscription.
  marketingContact,

  /// Show the business premises as a public pin on the map. Optional; the
  /// pin is deleted when consent is withdrawn.
  showMapLocation,

  /// Accepted the Terms of Use and Privacy Policy (the version is recorded
  /// with the consent).
  termsAccepted,
}

/// Reasons a customer may report a listing.
enum ReportReason {
  wrongPhoneNumber,
  incorrectDetails,
  noLongerInBusiness,
  spamOrMisleading,
  other,
}

/// Lifecycle of a customer report. Moderation happens outside this build.
enum ReportStatus {
  submitted,
  underReview,
  actioned,
  dismissed,
}

/// What a tracked in-app interaction represents.
///
/// Only button taps are recorded. A tap is never a call, lead, hire or job —
/// the app has no way to observe what happens after the dialer or WhatsApp
/// opens, so it must not claim to.
enum EngagementEventType {
  profileView,
  callButtonTap,
  whatsappButtonTap,
  shareTap,
  sponsorImpression,
  sponsorTap,
}

/// Surface that received a sponsored placement.
enum PromotionPlacement {
  homeFeatured,
  searchTop,
  categoryTop,
}

/// Pricing state of the monetization preview. No payment is collected in this
/// build.
enum PromotionState {
  draft,
  scheduled,
  active,
  expired,
}
