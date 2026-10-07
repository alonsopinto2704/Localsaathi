import '../models/account.dart';
import '../models/provider.dart';

/// Provider authentication.
///
/// The contract encodes the ownership rules the backend must enforce:
///
/// * one verified phone number = one account = one public profile, enforced on
///   the normalised E.164 value by a uniqueness constraint, never by a
///   client-side check;
/// * entering a number that already has a profile grants no access — a
///   successful OTP is required first;
/// * changing the registered number requires being signed in, verifying the new
///   number and passing a uniqueness check.
abstract class ProviderAuthRepository {
  /// The signed-in provider session, or null for guests.
  ///
  /// Restored from local storage on start-up; a production build would validate
  /// the token against the backend before trusting it.
  Future<ProviderSession?> restoreSession();

  /// Sends a one-time code to [rawPhone].
  ///
  /// Returns the challenge the UI needs (never the code, in production) or a
  /// validation error. This call does **not** reveal whether the number already
  /// has a profile: that only becomes visible after the code is verified, so
  /// the endpoint cannot be used to enumerate registered numbers.
  Future<OtpChallengeResult> requestOtp(String rawPhone);

  /// Verifies [code] for [challengeId].
  ///
  /// On success the session is established. [PhoneVerificationResult.existingProfileId]
  /// is non-null when the number already had a profile, which is how the UI
  /// routes an existing provider to sign-in instead of a new registration.
  Future<PhoneVerificationResult> verifyOtp({
    required String challengeId,
    required String code,
  });

  /// The signed-in provider's account.
  Future<ProviderAccount?> currentAccount();

  /// The signed-in provider's profile, if the account has one.
  Future<ProviderProfile?> currentProfile();

  /// Creates the account and its first profile after a successful verification.
  ///
  /// Re-checks uniqueness on the normalised number.
  Future<ProviderProfile> registerProfile({
    required RegistrationSubmission submission,
  });

  /// Starts a change of the registered number. Requires an active session, and
  /// the replacement number must pass the same uniqueness check.
  Future<OtpChallengeResult> requestPhoneNumberChange(String rawPhone);

  /// Completes the change with the code sent to the new number.
  ///
  /// Throws [DuplicatePhoneNumberException] when the new number already owns a
  /// profile.
  Future<ProviderAccount> confirmPhoneNumberChange({
    required String challengeId,
    required String code,
  });

  Future<void> signOut();

  /// Permanently deletes the provider account and its listing.
  Future<void> deleteAccount();
}

/// Implemented by repositories whose session can end without the user asking
/// (server-side revocation, expired refresh token). The session controller
/// registers itself so the UI can ask for a fresh sign-in while keeping the
/// provider's draft.
abstract interface class SessionRevocationNotifier {
  void setRevocationListener(void Function()? listener);
}

/// Outcome of requesting an OTP.
class OtpChallengeResult {
  const OtpChallengeResult._({this.challenge, this.error, this.retryAfter});

  factory OtpChallengeResult.success(OtpChallenge challenge) =>
      OtpChallengeResult._(challenge: challenge);

  factory OtpChallengeResult.failure(
    PhoneInputError error, {
    Duration? retryAfter,
  }) =>
      OtpChallengeResult._(error: error, retryAfter: retryAfter);

  final OtpChallenge? challenge;
  final PhoneInputError? error;

  /// For [PhoneInputError.rateLimited]: how long to wait before asking again.
  final Duration? retryAfter;

  bool get isSuccess => challenge != null;
}

/// Localised errors for phone entry.
enum PhoneInputError {
  empty,
  invalidFormat,
  unsupportedRegion,
  sendFailed,

  /// Too many codes requested; see [OtpChallengeResult.retryAfter].
  rateLimited,

  /// A number change needs a recent sign-in first.
  reauthRequired,
}

/// Outcome of verifying an OTP.
class PhoneVerificationResult {
  const PhoneVerificationResult({
    required this.session,
    required this.isNewAccount,
    required this.phoneVerified,
    this.existingProfileId,
    this.profile,
  });

  final ProviderSession session;

  /// True when this number had never registered before.
  final bool isNewAccount;

  final bool phoneVerified;

  /// Set when the number already owned a profile. The caller must treat this as
  /// "sign in", not "register again".
  final String? existingProfileId;

  final ProviderProfile? profile;

  bool get hasExistingProfile => existingProfileId != null;
}

/// Data collected in the onboarding wizard, submitted once at the end.
///
/// The draft is kept on-device while the provider fills it in; only a complete
/// submission creates a profile, so an abandoned wizard leaves no orphan
/// listing.
class RegistrationSubmission {
  const RegistrationSubmission({
    required this.phoneE164,
    required this.session,
    required this.displayName,
    required this.baseCityId,
    required this.baseLocalityId,
    required this.categoryIds,
    required this.serviceAreaIds,
    this.description,
    this.languages = const <String>[],
    this.workingHours,
    this.homeVisits = true,
    this.phoneDisplayConsented = false,
    this.whatsappEnabled = false,
    this.healthcareDetails,
    this.photos = const <ProviderPhoto>[],
    this.startingPrices = const <StartingPrice>[],
    this.termsAcceptedVersion,
  });

  final String phoneE164;
  final ProviderSession session;
  final String displayName;
  final String baseCityId;
  final String baseLocalityId;
  final List<String> categoryIds;
  final List<String> serviceAreaIds;
  final String? description;
  final List<String> languages;
  final WorkingHours? workingHours;
  final bool homeVisits;
  final bool phoneDisplayConsented;
  final bool whatsappEnabled;
  final HealthcareDetails? healthcareDetails;
  final List<ProviderPhoto> photos;
  final List<StartingPrice> startingPrices;

  /// Version of the Terms and Privacy Policy the provider accepted (and
  /// confirmed being 18+) before publishing. Recorded as a consent.
  final String? termsAcceptedVersion;
}
