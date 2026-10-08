import 'package:flutter/foundation.dart';

import '../../core/utils/phone_number.dart';
import '../../domain/models/account.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/profile_support_repositories.dart';
import '../../domain/repositories/provider_repository.dart';

/// Where the provider is in the sign-in journey.
enum SessionStatus {
  /// No session.
  signedOut,

  /// A code has been sent and we are waiting for it.
  awaitingOtp,

  /// Verified, but this phone number has no profile yet: the wizard is next.
  needsProfile,

  /// Verified with an existing profile.
  active,

  /// Verified, but moderation has suspended the listing. The owner can sign in
  /// and read their own state; publishing is blocked server-side.
  suspended,
}

/// Provider authentication and the signed-in provider's own listing.
///
/// Owns every rule that protects a provider's identity:
///
/// * a number that already has a profile is never opened on the strength of
///   typing it — [verifyCode] is the only path that can produce
///   [SessionStatus.active] or expose [existingProfileId];
/// * registering twice with the same normalised number surfaces
///   [duplicateNumberMessage] and switches the UI to "verify to sign in";
/// * every listing mutation goes through the repository, which re-checks
///   ownership against the session rather than trusting this class.
class SessionController extends ChangeNotifier {
  SessionController({
    required ProviderAuthRepository auth,
    required ProviderRepository providers,
    required ConsentRepository consents,
    required ProviderDraftRepository drafts,
  })  : _auth = auth,
        _providers = providers,
        _consents = consents,
        _drafts = drafts {
    final ProviderAuthRepository repo = auth;
    if (repo is SessionRevocationNotifier) {
      (repo as SessionRevocationNotifier)
          .setRevocationListener(handleSessionLost);
    }
  }

  final ProviderAuthRepository _auth;
  final ProviderRepository _providers;
  final ConsentRepository _consents;

  /// The onboarding draft is device state holding a phone number; it must not
  /// outlive the person who signed out or deleted their account (phase 003).
  final ProviderDraftRepository _drafts;

  SessionStatus _status = SessionStatus.signedOut;
  ProviderSession? _session;
  ProviderAccount? _account;
  ProviderProfile? _profile;
  OtpChallenge? _challenge;

  /// Set when the number just verified already owned a profile.
  String? _existingProfileId;

  bool _isBusy = false;
  String? _errorKey;

  /// Bumped whenever the signed-in identity changes (sign-out, deletion,
  /// revocation, a new restore). An async operation that started under an
  /// older epoch must not write its result back (phase 059).
  int _epoch = 0;

  /// Earliest time another code may be requested, when the server or the local
  /// pacing said to wait.
  DateTime? _resendAvailableAt;

  /// True when the session ended without the user asking (revoked/expired); the
  /// UI should ask for a fresh sign-in and keep the draft (phase 050).
  bool _sessionLost = false;

  /// Normalised number the pending challenge was sent to, for display only.
  String? _pendingPhoneE164;

  // -------------------------------------------------------------- state
  SessionStatus get status => _status;

  ProviderSession? get session => _session;

  ProviderAccount? get account => _account;

  ProviderProfile? get profile => _profile;

  /// Non-null only after a *successful* verification of a number that already
  /// had a profile. That ordering is what prevents number enumeration.
  String? get existingProfileId => _existingProfileId;

  bool get isBusy => _isBusy;

  /// A string key the UI localizes, rather than a pre-formatted English
  /// message, so errors stay translatable.
  String? get errorKey => _errorKey;

  String? get pendingPhoneE164 => _pendingPhoneE164;

  /// Formatted number the code was sent to.
  String? get pendingPhonePretty =>
      _pendingPhoneE164 == null ? null : PhoneUtils.formatPretty(_pendingPhoneE164!);

  bool get isSignedIn =>
      _status == SessionStatus.active ||
      _status == SessionStatus.needsProfile ||
      _status == SessionStatus.suspended;

  bool get hasProfile => _profile != null;

  bool get canPublish => _profile?.phoneDisplayConsented ?? false;

  /// Development-only code to display on screen. Null in a production build
  /// and for any live challenge (which never carries a code).
  String? get developmentCodeHint {
    final String? code = _challenge?.simulatedCode;
    return (code == null || code.isEmpty) ? null : code;
  }

  /// Seconds until another code may be requested; 0 when allowed now.
  int get resendWaitSeconds {
    final DateTime? at = _resendAvailableAt;
    if (at == null) return 0;
    final int left = at.difference(DateTime.now()).inSeconds;
    return left > 0 ? left : 0;
  }

  bool get sessionLost => _sessionLost;

  bool get isSuspended => _status == SessionStatus.suspended;

  // --------------------------------------------------------------- lifecycle
  /// Rebuilds state from the verified server identity (phase 051). Nothing
  /// cached is trusted: ids, profile and account are all re-read, and any
  /// failure ends in a guest state rather than another provider's owner view.
  Future<void> restore() async {
    final int epoch = ++_epoch;
    _clearOwnerState();
    try {
      final ProviderSession? session = await _auth.restoreSession();
      if (epoch != _epoch) return;
      if (session != null) {
        final ProviderAccount? account = await _auth.currentAccount();
        final ProviderProfile? profile =
            account == null ? null : await _auth.currentProfile();
        if (epoch != _epoch) return;
        if (account != null) {
          _session = session;
          _account = account;
          _profile = profile;
        } else {
          // Authenticated token, but the account no longer exists.
          await _auth.signOut();
        }
      }
    } on Object {
      if (epoch != _epoch) return;
      _clearOwnerState();
    }
    _status = _statusFor(_session, _account, _profile);
    notifyListeners();
  }

  /// Called when the auth layer reports the session was revoked or expired.
  /// Unlike [signOut] this keeps the onboarding draft so the provider can sign
  /// in again and continue.
  void handleSessionLost() {
    _epoch++;
    _clearOwnerState();
    _challenge = null;
    _pendingPhoneE164 = null;
    _sessionLost = true;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  void _clearOwnerState() {
    _session = null;
    _account = null;
    _profile = null;
    _existingProfileId = null;
    _sessionLost = false;
  }

  static SessionStatus _statusFor(
    ProviderSession? session,
    ProviderAccount? account,
    ProviderProfile? profile,
  ) {
    if (session == null) return SessionStatus.signedOut;
    if (account?.isSuspended ?? false) return SessionStatus.suspended;
    return profile == null ? SessionStatus.needsProfile : SessionStatus.active;
  }

  // ------------------------------------------------------------ phone entry
  /// Requests a code. Never reveals whether the number is already registered.
  Future<bool> requestCode(String rawPhone) async {
    // A second tap while a request is running is ignored (phase 046).
    if (_isBusy) return false;
    final int epoch = _epoch;
    _setBusy(true);
    _errorKey = null;
    final OtpChallengeResult result = await _auth.requestOtp(rawPhone);
    _setBusy(false);
    if (epoch != _epoch) return false;

    if (!result.isSuccess) {
      _errorKey = switch (result.error) {
        PhoneInputError.empty => 'fieldRequired',
        PhoneInputError.unsupportedRegion => 'invalidPhoneNumber',
        PhoneInputError.invalidFormat => 'invalidPhoneNumber',
        PhoneInputError.sendFailed => 'errorUnknown',
        PhoneInputError.rateLimited => 'otpRateLimited',
        PhoneInputError.reauthRequired => 'reauthRequired',
        null => 'errorUnknown',
      };
      if (result.error == PhoneInputError.rateLimited) {
        _resendAvailableAt =
            DateTime.now().add(result.retryAfter ?? const Duration(seconds: 60));
      }
      notifyListeners();
      return false;
    }

    _sessionLost = false;
    _resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));
    _challenge = result.challenge;
    _pendingPhoneE164 = result.challenge!.phoneE164;
    _status = SessionStatus.awaitingOtp;
    notifyListeners();
    return true;
  }

  /// Verifies the code. This is the gate for every piece of profile access.
  Future<bool> verifyCode(String code) async {
    final OtpChallenge? challenge = _challenge;
    if (challenge == null) {
      _errorKey = 'errorUnknown';
      notifyListeners();
      return false;
    }

    if (_isBusy) return false;
    final int epoch = _epoch;
    _setBusy(true);
    _errorKey = null;
    try {
      final PhoneVerificationResult result = await _auth.verifyOtp(
        challengeId: challenge.id,
        code: code,
      );
      if (epoch != _epoch) return false;
      // A different number than the saved draft's means a different person:
      // never carry the previous person's draft into this account.
      final ProviderDraft? draft = await _drafts.load();
      if (draft != null && draft.phoneE164 != result.session.phoneE164) {
        await _drafts.clear();
      }
      _session = result.session;
      _account = await _auth.currentAccount();
      _profile = result.profile;
      _existingProfileId = result.existingProfileId;
      _challenge = null;
      _status = _statusFor(_session, _account, _profile);
      return true;
    } on OtpException catch (error) {
      if (epoch != _epoch) return false;
      _errorKey = switch (error.reason) {
        OtpFailure.invalid => 'otpInvalid',
        OtpFailure.expired => 'otpExpired',
        OtpFailure.attemptsExceeded => 'otpAttemptsExceeded',
        OtpFailure.unknown => 'errorUnknown',
      };
      // An exhausted or expired challenge is discarded so the UI returns to
      // phone entry rather than offering another guess.
      if (error.reason == OtpFailure.attemptsExceeded ||
          error.reason == OtpFailure.expired) {
        _challenge = null;
        _status = SessionStatus.signedOut;
      }
      return false;
    } on Object {
      _errorKey = 'errorUnknown';
      return false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  /// Re-sends a code to the same number.
  Future<bool> resendCode() async {
    final String? e164 = _pendingPhoneE164;
    if (e164 == null) return false;
    final bool ok = await requestCode(e164);
    return ok;
  }

  /// Abandons the pending challenge and returns to phone entry.
  void cancelVerification() {
    _challenge = null;
    _pendingPhoneE164 = null;
    _errorKey = null;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  void clearError() {
    if (_errorKey == null) return;
    _errorKey = null;
    notifyListeners();
  }

  /// The duplicate-number copy. Returning the string key keeps localization in
  /// the UI while the rule stays in the domain.
  static const String duplicateNumberMessageKey = 'duplicateNumberMessage';
  static const String duplicateNumberTitleKey = 'duplicateNumberTitle';

  // --------------------------------------------------------- profile writes
  /// Creates the provider's first profile from the wizard submission.
  ///
  /// Returns null and sets [errorKey] on failure; a duplicate number surfaces
  /// as [duplicateNumberMessageKey] rather than a generic error.
  Future<ProviderProfile?> createProfile(RegistrationSubmission submission) async {
    final int epoch = _epoch;
    _setBusy(true);
    _errorKey = null;
    try {
      final ProviderProfile profile =
          await _auth.registerProfile(submission: submission);
      // The identity changed while the request was in flight: the created
      // profile belongs to the previous session and must not be shown here.
      if (epoch != _epoch) return null;
      _profile = profile;
      _session = await _auth.restoreSession();
      _account = await _auth.currentAccount();
      _status = SessionStatus.active;
      return profile;
    } on DuplicatePhoneNumberException {
      _errorKey = duplicateNumberMessageKey;
      return null;
    } on RepositoryException catch (error) {
      _errorKey = _keyForRepositoryError(error);
      return null;
    } on Object {
      _errorKey = 'errorUnknown';
      return null;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  /// Saves provider-authored edits. Ownership is re-checked in the repository.
  Future<bool> updateProfile(ProviderProfile profile) async {
    final ProviderSession? session = _session;
    if (session == null) {
      _errorKey = 'errorUnknown';
      notifyListeners();
      return false;
    }
    final int epoch = _epoch;
    _setBusy(true);
    _errorKey = null;
    try {
      final ProviderProfile updated = await _providers.updateProfile(
        profile: profile,
        session: session,
      );
      if (epoch != _epoch) return false;
      _profile = updated;
      // Consents are re-recorded whenever the provider changes their visibility
      // choices, so the audit trail reflects the latest decision.
      await _consents.record(
        providerId: updated.id,
        kind: ConsentKind.displayPhoneNumber,
        granted: updated.phoneDisplayConsented,
        phoneE164: updated.phoneE164,
      );
      await _consents.record(
        providerId: updated.id,
        kind: ConsentKind.whatsappContact,
        granted: updated.whatsappEnabled,
        phoneE164: updated.phoneE164,
      );
      await _consents.record(
        providerId: updated.id,
        kind: ConsentKind.showMapLocation,
        granted: updated.mapLocation != null,
        phoneE164: updated.phoneE164,
      );
      return true;
    } on RepositoryException catch (error) {
      _errorKey = _keyForRepositoryError(error);
      return false;
    } on Object {
      _errorKey = 'errorUnknown';
      return false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<bool> publish() async {
    final ProviderSession? session = _session;
    final String? profileId = _profile?.id;
    if (session == null || profileId == null) return false;

    final int epoch = _epoch;
    _setBusy(true);
    _errorKey = null;
    try {
      final ProviderProfile next = await _providers.publish(
        profileId: profileId,
        session: session,
      );
      if (epoch != _epoch) return false;
      _profile = next;
      return true;
    } on RepositoryException catch (error) {
      _errorKey = _keyForRepositoryError(error);
      return false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  /// Pauses or resumes the listing. Pausing is what removes it from customer
  /// results; nothing else changes.
  Future<bool> setListingStatus(ListingStatus status) async {
    final ProviderSession? session = _session;
    final String? profileId = _profile?.id;
    if (session == null || profileId == null) return false;

    final int epoch = _epoch;
    _setBusy(true);
    try {
      final ProviderProfile next = await _providers.setListingStatus(
        profileId: profileId,
        status: status,
        session: session,
      );
      if (epoch != _epoch) return false;
      _profile = next;
      return true;
    } on RepositoryException catch (error) {
      _errorKey = _keyForRepositoryError(error);
      return false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<bool> setAvailability(AvailabilityStatus availability) async {
    final ProviderSession? session = _session;
    final String? profileId = _profile?.id;
    if (session == null || profileId == null) return false;

    final int epoch = _epoch;
    _setBusy(true);
    try {
      final ProviderProfile next = await _providers.setAvailability(
        profileId: profileId,
        availability: availability,
        session: session,
      );
      if (epoch != _epoch) return false;
      _profile = next;
      return true;
    } on RepositoryException catch (error) {
      _errorKey = _keyForRepositoryError(error);
      return false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  /// Deletes the listing, which also releases the phone number.
  Future<bool> deleteListing() async {
    final ProviderSession? session = _session;
    final String? profileId = _profile?.id;
    if (session == null || profileId == null) return false;

    _setBusy(true);
    try {
      await _providers.deleteListing(profileId: profileId, session: session);
      _profile = null;
      _session = session.copyWith(clearProfileId: true);
      _account = await _auth.currentAccount();
      _status = SessionStatus.needsProfile;
      return true;
    } on RepositoryException catch (error) {
      _errorKey = _keyForRepositoryError(error);
      return false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  /// Deletes the provider account entirely. Saved providers on the device and
  /// the customer's browsing are untouched.
  Future<void> deleteAccount() async {
    _setBusy(true);
    try {
      await _auth.deleteAccount();
      _epoch++;
      await _drafts.clear();
      _profile = null;
      _account = null;
      _session = null;
      _challenge = null;
      _pendingPhoneE164 = null;
      _existingProfileId = null;
      _status = SessionStatus.signedOut;
      _errorKey = null;
    } on RepositoryException catch (error) {
      // Nothing was deleted (e.g. a recent sign-in is required first): the
      // account and the draft stay exactly as they were.
      _errorKey = _keyForRepositoryError(error);
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _epoch++;
    await _auth.signOut();
    await _drafts.clear();
    _session = null;
    _account = null;
    _profile = null;
    _challenge = null;
    _pendingPhoneE164 = null;
    _existingProfileId = null;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }

  /// Re-reads the signed-in profile, e.g. after the wizard publishes.
  Future<void> refreshProfile() async {
    _account = await _auth.currentAccount();
    _profile = await _auth.currentProfile();
    if (_profile != null) {
      _status = SessionStatus.active;
    } else if (_session != null) {
      _status = SessionStatus.needsProfile;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- internals
  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  static String _keyForRepositoryError(RepositoryException error) =>
      switch (error.code) {
        RepositoryErrorCode.notAuthenticated => 'errorUnknown',
        RepositoryErrorCode.notOwner => 'errorUnknown',
        RepositoryErrorCode.notFound => 'errorNotFound',
        RepositoryErrorCode.validationFailed => 'fieldRequired',
        RepositoryErrorCode.listingNotPublishable => 'consentShowPhoneRequired',
        RepositoryErrorCode.locationNotActive => 'cityNotActiveYet',
        RepositoryErrorCode.categoryNotAllowed => 'selectAtLeastOneCategory',
        RepositoryErrorCode.suspended => 'errorUnknown',
        RepositoryErrorCode.conflict => duplicateNumberMessageKey,
        RepositoryErrorCode.reauthRequired => 'reauthRequired',
        RepositoryErrorCode.rateLimited => 'otpRateLimited',
        RepositoryErrorCode.featureDisabled => 'featureDisabled',
        RepositoryErrorCode.consentRequired => 'consentShowPhoneRequired',
        RepositoryErrorCode.unavailable => 'errorUnknown',
      };
}
