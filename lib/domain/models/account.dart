export 'enums.dart';

/// A provider's sign-in identity.
///
/// Deliberately excludes the profile: the account owns the phone identity and
/// points at exactly one profile. Enforcing "one verified number = one account
/// = one public profile" is a single check on [phoneE164].
class ProviderAccount {
  const ProviderAccount({
    required this.id,
    required this.phoneE164,
    required this.createdAt,
    this.profileId,
    this.phoneVerifiedAt,
    this.lastSignedInAt,
    this.isSuspended = false,
    this.suspensionReason,
  });

  final String id;

  /// Normalised E.164. Unique across accounts.
  final String phoneE164;

  final DateTime createdAt;

  /// The one profile this account owns, once created.
  final String? profileId;

  final DateTime? phoneVerifiedAt;
  final DateTime? lastSignedInAt;

  /// Set by moderation. A suspended account cannot publish.
  final bool isSuspended;
  final String? suspensionReason;

  bool get isPhoneVerified => phoneVerifiedAt != null;

  bool get hasProfile => profileId != null;

  ProviderAccount copyWith({
    String? phoneE164,
    String? profileId,
    DateTime? phoneVerifiedAt,
    DateTime? lastSignedInAt,
    bool? isSuspended,
    String? suspensionReason,
  }) =>
      ProviderAccount(
        id: id,
        phoneE164: phoneE164 ?? this.phoneE164,
        createdAt: createdAt,
        profileId: profileId ?? this.profileId,
        phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
        lastSignedInAt: lastSignedInAt ?? this.lastSignedInAt,
        isSuspended: isSuspended ?? this.isSuspended,
        suspensionReason: suspensionReason ?? this.suspensionReason,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'phoneE164': phoneE164,
        'createdAt': createdAt.toIso8601String(),
        'profileId': profileId,
        'phoneVerifiedAt': phoneVerifiedAt?.toIso8601String(),
        'lastSignedInAt': lastSignedInAt?.toIso8601String(),
        'isSuspended': isSuspended,
        'suspensionReason': suspensionReason,
      };

  static ProviderAccount fromJson(Map<String, dynamic> json) => ProviderAccount(
        id: json['id'] as String,
        phoneE164: json['phoneE164'] as String,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        profileId: json['profileId'] as String?,
        phoneVerifiedAt:
            DateTime.tryParse(json['phoneVerifiedAt'] as String? ?? ''),
        lastSignedInAt:
            DateTime.tryParse(json['lastSignedInAt'] as String? ?? ''),
        isSuspended: (json['isSuspended'] as bool?) ?? false,
        suspensionReason: json['suspensionReason'] as String?,
      );
}

/// The signed-in provider's session, persisted locally.
class ProviderSession {
  const ProviderSession({
    required this.accountId,
    required this.phoneE164,
    required this.signedInAt,
    this.profileId,
  });

  final String accountId;
  final String phoneE164;
  final DateTime signedInAt;
  final String? profileId;

  ProviderSession copyWith({String? profileId}) => ProviderSession(
        accountId: accountId,
        phoneE164: phoneE164,
        signedInAt: signedInAt,
        profileId: profileId ?? this.profileId,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accountId': accountId,
        'phoneE164': phoneE164,
        'signedInAt': signedInAt.toIso8601String(),
        'profileId': profileId,
      };

  static ProviderSession? fromJson(Map<String, dynamic> json) {
    final Object? accountId = json['accountId'];
    final Object? phone = json['phoneE164'];
    if (accountId is! String || phone is! String) return null;
    return ProviderSession(
      accountId: accountId,
      phoneE164: phone,
      signedInAt:
          DateTime.tryParse(json['signedInAt'] as String? ?? '') ??
              DateTime.now(),
      profileId: json['profileId'] as String?,
    );
  }
}

/// A one-time-code challenge.
///
/// DEVELOPMENT ONLY. In production the code never leaves the backend; the
/// client sends the entered code and receives a session token.
class OtpChallenge {
  const OtpChallenge({
    required this.id,
    required this.phoneE164,
    required this.issuedAt,
    required this.expiresAt,
    required this.simulatedCode,
    this.attempts = 0,
    this.consumedAt,
  });

  final String id;
  final String phoneE164;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// Never persisted or logged in a production build.
  final String simulatedCode;

  final int attempts;
  final DateTime? consumedAt;

  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);

  bool get isConsumed => consumedAt != null;

  OtpChallenge copyWith({int? attempts, DateTime? consumedAt}) => OtpChallenge(
        id: id,
        phoneE164: phoneE164,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        simulatedCode: simulatedCode,
        attempts: attempts ?? this.attempts,
        consumedAt: consumedAt ?? this.consumedAt,
      );
}

/// Why a provider had to be routed to verification instead of a new listing.
///
/// Returning this instead of an error is what lets the UI show the exact
/// required copy: "This number already has a profile. Verify it to sign in."
class DuplicatePhoneNumberException implements Exception {
  const DuplicatePhoneNumberException(this.e164);

  final String e164;

  @override
  String toString() => 'DuplicatePhoneNumberException($e164)';
}

/// Thrown when an OTP is wrong, expired or exhausted.
class OtpException implements Exception {
  const OtpException(this.reason);

  final OtpFailure reason;

  @override
  String toString() => 'OtpException(${reason.name})';
}

enum OtpFailure { invalid, expired, attemptsExceeded, unknown }

/// Thrown when a request would break a business rule the backend must own.
class RepositoryException implements Exception {
  const RepositoryException(this.code, [this.message]);

  final RepositoryErrorCode code;
  final String? message;

  @override
  String toString() => 'RepositoryException(${code.name}${message == null ? '' : ': $message'})';
}

enum RepositoryErrorCode {
  notAuthenticated,
  notOwner,
  notFound,
  validationFailed,
  listingNotPublishable,
  locationNotActive,
  categoryNotAllowed,
  suspended,
  conflict,
}

/// Result of attempting to start provider registration/sign-in with a number.
class PhoneRegistrationOutcome {
  const PhoneRegistrationOutcome._({
    required this.kind,
    this.challenge,
    this.existingProfileId,
    this.error,
  });

  factory PhoneRegistrationOutcome.newAccount(OtpChallenge challenge) =>
      PhoneRegistrationOutcome._(
        kind: PhoneRegistrationKind.newAccount,
        challenge: challenge,
      );

  /// The number already has a profile: the caller must verify before any
  /// access is granted. No profile data is returned here.
  factory PhoneRegistrationOutcome.existingProfile({
    required OtpChallenge challenge,
    required String existingProfileId,
  }) =>
      PhoneRegistrationOutcome._(
        kind: PhoneRegistrationKind.existingProfile,
        challenge: challenge,
        existingProfileId: existingProfileId,
      );

  factory PhoneRegistrationOutcome.failed(RepositoryErrorCode error) =>
      PhoneRegistrationOutcome._(
        kind: PhoneRegistrationKind.failed,
        error: error,
      );

  final PhoneRegistrationKind kind;
  final OtpChallenge? challenge;
  final String? existingProfileId;
  final RepositoryErrorCode? error;

  bool get isDuplicate => kind == PhoneRegistrationKind.existingProfile;
}

enum PhoneRegistrationKind { newAccount, existingProfile, failed }
