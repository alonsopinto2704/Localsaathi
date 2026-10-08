import 'dart:math';

import '../../core/utils/phone_number.dart';
import '../../domain/models/account.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_gateway.dart';
import 'otp_challenge_book.dart';
import 'otp_cooldown.dart';
import 'session_refresher.dart';
import 'wire.dart';

/// Live phone-OTP identity on top of an [AuthGateway] (phases 041-057).
///
/// Responsibilities, and what deliberately lives elsewhere:
///
/// * **Server owns the secret.** The code is generated, delivered, expired and
///   attempt-limited by Supabase Auth; this class never sees or stores one and
///   `OtpChallenge.simulatedCode` is always empty.
/// * **Enumeration resistance.** `requestOtp` never reads profile data and
///   returns the same shape for every well-formed number. Ownership
///   (`existingProfileId`, suspension, deletion) is read only after a verified
///   code, from `my_account` / `my_profile`, which are bound to `auth.uid()`.
/// * **No local success.** A timeout, offline error or elapsed countdown is
///   never treated as verification; only a session returned by the server is.
/// * **No guest fallback.** Protected calls refresh the token first and fail
///   with `notAuthenticated` if the session is gone; they never degrade to
///   mock or anonymous behaviour.
/// * **Nothing sensitive in logs or exceptions:** codes, tokens and full
///   numbers are never interpolated into messages.
class SupabaseProviderAuthRepository
    implements ProviderAuthRepository, SessionRevocationNotifier {
  SupabaseProviderAuthRepository({
    required AuthGateway gateway,
    required OtpCooldown cooldown,
    SessionRefresher? refresher,
    OtpChallengeBook? book,
    DateTime Function()? now,
    Random? random,
    this.codeLength = 6,
  })  : _gateway = gateway,
        _cooldown = cooldown,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure(),
        _book = book ?? OtpChallengeBook(now: now) {
    _refresher = refresher ??
        SessionRefresher(
          gateway: gateway,
          now: now,
          onRevoked: () => _onRevoked?.call(),
        );
  }

  final AuthGateway _gateway;
  final OtpCooldown _cooldown;
  final DateTime Function() _now;
  final Random _random;
  final OtpChallengeBook _book;
  late final SessionRefresher _refresher;
  final int codeLength;

  /// Sends in progress, keyed by number: a second tap joins the first.
  final Map<String, Future<OtpChallengeResult>> _sending =
      <String, Future<OtpChallengeResult>>{};

  void Function()? _onRevoked;

  @override
  void setRevocationListener(void Function()? listener) =>
      _onRevoked = listener;

  String? _registerKey;
  String? _deleteKey;

  /// Exposed so tests and the composition root can share one refresher.
  SessionRefresher get refresher => _refresher;

  // ---------------------------------------------------------------- restore
  @override
  Future<ProviderSession?> restoreSession() async {
    final GatewaySession? session;
    try {
      session = await _gateway.restore();
    } on GatewayException catch (error) {
      // Offline at start-up: keep the stored credentials for the next attempt
      // but do not pretend to be signed in.
      if (error.kind == GatewayErrorKind.transient) return null;
      rethrow;
    }
    if (session == null) {
      _book.clear();
      return null;
    }
    // Ownership always comes from the server, never from a cached id.
    final ProviderAccount? account = await currentAccount();
    if (account == null) {
      // The token is valid but the user no longer exists (deleted elsewhere).
      await _endLocalSession();
      return null;
    }
    return _toProviderSession(session, account.profileId);
  }

  // ------------------------------------------------------------ request OTP
  @override
  Future<OtpChallengeResult> requestOtp(String rawPhone) {
    final PhoneInputError? invalid = _validate(rawPhone);
    if (invalid != null) {
      return Future<OtpChallengeResult>.value(
        OtpChallengeResult.failure(invalid),
      );
    }
    final String e164 = PhoneUtils.tryNormalize(rawPhone)!.e164;
    return _sending[e164] ??= _send(e164, ChallengePurpose.signIn)
        .whenComplete(() {
      // A block body: returning the removed future would make it await itself.
      _sending.remove(e164);
    });
  }

  Future<OtpChallengeResult> _send(String e164, ChallengePurpose purpose) async {
    final Duration wait = _cooldown.remaining();
    if (wait > Duration.zero) {
      return OtpChallengeResult.failure(
        PhoneInputError.rateLimited,
        retryAfter: wait,
      );
    }
    final String? boundUser = _gateway.currentSession?.userId;
    bool decoy = false;
    try {
      if (purpose == ChallengePurpose.phoneChange) {
        await _gateway.sendPhoneChangeOtp(e164);
      } else {
        await _gateway.sendOtp(e164);
      }
    } on GatewayException catch (error) {
      switch (error.kind) {
        case GatewayErrorKind.rateLimited:
          await _cooldown.markRateLimited(error.retryAfter);
          return OtpChallengeResult.failure(
            PhoneInputError.rateLimited,
            retryAfter: _cooldown.remaining(),
          );
        case GatewayErrorKind.reauthRequired:
          return OtpChallengeResult.failure(PhoneInputError.reauthRequired);
        case GatewayErrorKind.phoneConflict:
          // Do not tell the caller the number belongs to someone else: look
          // exactly like a send and fail at verification (phase 048/052).
          decoy = true;
        case GatewayErrorKind.sendRejected:
        case GatewayErrorKind.transient:
        case GatewayErrorKind.sessionRevoked:
        case GatewayErrorKind.invalidCode:
        case GatewayErrorKind.forbidden:
        case GatewayErrorKind.unknown:
          return OtpChallengeResult.failure(PhoneInputError.sendFailed);
      }
    }
    await _cooldown.markSent();
    return OtpChallengeResult.success(
      _book.issue(
        phoneE164: e164,
        purpose: purpose,
        boundUserId: boundUser,
        decoy: decoy,
      ),
    );
  }

  // ------------------------------------------------------------- verify OTP
  @override
  Future<PhoneVerificationResult> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    final ChallengeLookup challenge = _book.lookup(
      challengeId: challengeId,
      purpose: ChallengePurpose.signIn,
      currentUserId: _gateway.currentSession?.userId,
    );
    final String clean = _cleanCode(code);
    if (clean.length != codeLength) {
      throw const OtpException(OtpFailure.invalid);
    }
    if (challenge.decoy) _book.recordWrongCode(challengeId);

    final GatewaySession session;
    try {
      session = await _gateway.verifyOtp(challenge.phoneE164, clean);
    } on GatewayException catch (error) {
      switch (error.kind) {
        case GatewayErrorKind.invalidCode:
          _book.recordWrongCode(challengeId);
        case GatewayErrorKind.rateLimited:
          throw const OtpException(OtpFailure.attemptsExceeded);
        case GatewayErrorKind.sendRejected:
        case GatewayErrorKind.sessionRevoked:
        case GatewayErrorKind.reauthRequired:
        case GatewayErrorKind.phoneConflict:
        case GatewayErrorKind.forbidden:
        case GatewayErrorKind.transient:
        case GatewayErrorKind.unknown:
          // Outcome unknown (or not a code problem): the challenge stays so the
          // user can retry, and nothing is treated as verified.
          throw const OtpException(OtpFailure.unknown);
      }
    }
    _book.consume(challengeId);

    if (session.phoneE164.isNotEmpty && session.phoneE164 != challenge.phoneE164) {
      // The server authenticated an identity other than the one we asked for.
      await _endLocalSession();
      throw const OtpException(OtpFailure.unknown);
    }

    // Verified. Only now read ownership.
    final ProviderAccount? account;
    final ProviderProfile? profile;
    try {
      account = await currentAccount();
      profile = account == null ? null : await currentProfile();
    } on Object {
      await _endLocalSession();
      throw const OtpException(OtpFailure.unknown);
    }
    return PhoneVerificationResult(
      session: _toProviderSession(session, profile?.id ?? account?.profileId),
      isNewAccount: profile == null,
      phoneVerified: true,
      existingProfileId: profile?.id,
      profile: profile,
    );
  }

  // ------------------------------------------------------------ owner state
  @override
  Future<ProviderAccount?> currentAccount() async {
    if (_gateway.currentSession == null) return null;
    final Object? raw = await _protected(() => _gateway.rpc('my_account'));
    return raw is Map<String, dynamic> ? _accountFromJson(raw) : null;
  }

  @override
  Future<ProviderProfile?> currentProfile() async {
    if (_gateway.currentSession == null) return null;
    final Object? raw = await _protected(() => _gateway.rpc('my_profile'));
    return raw is Map<String, dynamic> ? ProviderProfile.fromJson(raw) : null;
  }

  @override
  Future<ProviderProfile> registerProfile({
    required RegistrationSubmission submission,
  }) async {
    final GatewaySession? session = _gateway.currentSession;
    if (session == null || session.phoneE164 != submission.phoneE164) {
      throw const RepositoryException(RepositoryErrorCode.notAuthenticated);
    }
    final String key = _registerKey ??= _newKey();
    final Object? raw = await _protected(
      () => _gateway.rpc('register_profile', <String, dynamic>{
        'p_submission': <String, dynamic>{
          ..._submissionJson(submission),
          'idempotencyKey': key,
        },
      }),
    );
    if (raw is! Map<String, dynamic>) {
      throw const RepositoryException(RepositoryErrorCode.unavailable);
    }
    final ProviderProfile profile = ProviderProfile.fromJson(raw);
    _registerKey = null;
    final String? terms = submission.termsAcceptedVersion;
    if (terms != null) {
      await _protected(
        () => _gateway.rpc('record_terms_acceptance', <String, dynamic>{
          'p_profile_id': profile.id,
          'p_version': terms,
        }),
      );
    }
    return profile;
  }

  // ----------------------------------------------------------- phone change
  @override
  Future<OtpChallengeResult> requestPhoneNumberChange(String rawPhone) async {
    final GatewaySession? session = _gateway.currentSession;
    if (session == null) {
      return OtpChallengeResult.failure(PhoneInputError.sendFailed);
    }
    final PhoneInputError? invalid = _validate(rawPhone);
    if (invalid != null) return OtpChallengeResult.failure(invalid);
    final String e164 = PhoneUtils.tryNormalize(rawPhone)!.e164;
    if (e164 == session.phoneE164) {
      return OtpChallengeResult.failure(PhoneInputError.invalidFormat);
    }
    try {
      // Server-side recency gate (phase 055): without a fresh grant the
      // database refuses the number change even if this call is skipped.
      await _protected(() => _gateway.rpc(
            'request_sensitive_action',
            <String, dynamic>{'p_action': 'phone_change'},
          ),);
    } on RepositoryException catch (error) {
      return OtpChallengeResult.failure(
        error.code == RepositoryErrorCode.reauthRequired
            ? PhoneInputError.reauthRequired
            : PhoneInputError.sendFailed,
      );
    }
    return _sending['change:$e164'] ??=
        _send(e164, ChallengePurpose.phoneChange)
            .whenComplete(() {
      _sending.remove('change:$e164');
    });
  }

  @override
  Future<ProviderAccount> confirmPhoneNumberChange({
    required String challengeId,
    required String code,
  }) async {
    final GatewaySession? before = _gateway.currentSession;
    if (before == null) {
      throw const RepositoryException(RepositoryErrorCode.notAuthenticated);
    }
    final ChallengeLookup challenge = _book.lookup(
      challengeId: challengeId,
      purpose: ChallengePurpose.phoneChange,
      currentUserId: before.userId,
    );
    final String clean = _cleanCode(code);
    if (clean.length != codeLength) throw const OtpException(OtpFailure.invalid);
    if (challenge.decoy) _book.recordWrongCode(challengeId);
    try {
      await _gateway.verifyPhoneChange(challenge.phoneE164, clean);
    } on GatewayException catch (error) {
      switch (error.kind) {
        case GatewayErrorKind.invalidCode:
          _book.recordWrongCode(challengeId);
        case GatewayErrorKind.phoneConflict:
          // Conflict after proof of control: ownership of the OLD number and
          // its profile is untouched; nothing moved.
          _book.consume(challengeId);
          throw DuplicatePhoneNumberException(challenge.phoneE164);
        case GatewayErrorKind.reauthRequired:
          throw const RepositoryException(RepositoryErrorCode.reauthRequired);
        case GatewayErrorKind.rateLimited:
          throw const OtpException(OtpFailure.attemptsExceeded);
        case GatewayErrorKind.sendRejected:
        case GatewayErrorKind.sessionRevoked:
        case GatewayErrorKind.forbidden:
        case GatewayErrorKind.transient:
        case GatewayErrorKind.unknown:
          throw const OtpException(OtpFailure.unknown);
      }
    }
    _book.consume(challengeId);
    final ProviderAccount? account = await currentAccount();
    if (account == null) {
      throw const RepositoryException(RepositoryErrorCode.notFound);
    }
    return account;
  }

  // ----------------------------------------------------------- sign out etc.
  @override
  Future<void> signOut() => _endLocalSession();

  @override
  Future<void> deleteAccount() async {
    if (_gateway.currentSession == null) return;
    // A retry reuses the key of the attempt in progress and skips the grant:
    // the server resumes the same deletion job and needs no new confirmation,
    // and after a success whose response was lost the user no longer exists, so
    // asking for a new grant would only fail.
    final bool retry = _deleteKey != null;
    if (!retry) {
      await _protected(() => _gateway.rpc(
            'request_sensitive_action',
            <String, dynamic>{'p_action': 'delete_account'},
          ),);
      _deleteKey = _newKey();
    }
    final Map<String, dynamic> result;
    try {
      result = await _gateway.deleteAccountRequest(idempotencyKey: _deleteKey!);
    } on GatewayException catch (error) {
      if (error.kind == GatewayErrorKind.reauthRequired) _deleteKey = null;
      if (retry && error.kind == GatewayErrorKind.sessionRevoked) {
        // The earlier attempt succeeded and the account is already gone.
        await _endLocalSession();
        return;
      }
      throw repositoryErrorForGateway(error);
    } on GatewayRpcException catch (error) {
      throw repositoryErrorForRpc(error);
    }
    if (result['ok'] != true) {
      throw const RepositoryException(RepositoryErrorCode.unavailable);
    }
    await _endLocalSession();
  }

  // ------------------------------------------------------------- internals
  Future<void> _endLocalSession() async {
    _refresher.invalidate();
    _book.clear();
    _registerKey = null;
    _deleteKey = null;
    await _cooldown.clear();
    try {
      await _gateway.signOut();
    } on GatewayException {
      // The server may already have forgotten the user; local state is cleared
      // by the gateway regardless.
    }
  }

  Future<T> _protected<T>(Future<T> Function() op) async {
    try {
      await _refresher.ensureFresh();
      return await op();
    } on GatewayException catch (error) {
      throw repositoryErrorForGateway(error);
    } on GatewayRpcException catch (error) {
      throw repositoryErrorForRpc(error);
    }
  }

  PhoneInputError? _validate(String rawPhone) {
    if (rawPhone.trim().isEmpty) return PhoneInputError.empty;
    PhoneValidationError? why;
    final NormalizedPhone? phone =
        PhoneUtils.tryNormalize(rawPhone, onError: (e) => why = e);
    if (phone != null) return null;
    return why == PhoneValidationError.unsupportedDialCode
        ? PhoneInputError.unsupportedRegion
        : PhoneInputError.invalidFormat;
  }

  /// Accepts pasted codes with spaces or non-ASCII digits ("१२३ ४५६").
  String _cleanCode(String raw) => PhoneUtils.digitsOf(raw);

  ProviderSession _toProviderSession(GatewaySession s, String? profileId) =>
      ProviderSession(
        accountId: s.userId,
        phoneE164: s.phoneE164,
        signedInAt: s.signedInAt ?? s.authenticatedAt,
        profileId: profileId,
      );

  ProviderAccount _accountFromJson(Map<String, dynamic> json) {
    String phone = (json['phoneE164'] as String?) ?? '';
    // GoTrue stores numbers without '+'; the contract says E.164 with it.
    if (phone.isNotEmpty && !phone.startsWith('+')) phone = '+$phone';
    return ProviderAccount(
      id: json['id'] as String,
      phoneE164: phone,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          _now(),
      profileId: json['profileId'] as String?,
      phoneVerifiedAt:
          DateTime.tryParse((json['phoneVerifiedAt'] as String?) ?? ''),
      lastSignedInAt:
          DateTime.tryParse((json['lastSignedInAt'] as String?) ?? ''),
      isSuspended: (json['isSuspended'] as bool?) ?? false,
      suspensionReason: json['suspensionReason'] as String?,
    );
  }

  Map<String, dynamic> _submissionJson(RegistrationSubmission s) =>
      <String, dynamic>{
        'displayName': s.displayName.trim(),
        'baseCityId': s.baseCityId,
        'baseLocalityId': s.baseLocalityId,
        'categoryIds': s.categoryIds,
        'serviceAreaIds': s.serviceAreaIds,
        'description': s.description,
        'languages': s.languages,
        'homeVisits': s.homeVisits,
        'whatsappEnabled': s.whatsappEnabled,
        'phoneDisplayConsented': s.phoneDisplayConsented,
        'workingHours': s.workingHours?.toJson(),
        'photoCaptions': <String>[for (final ProviderPhoto p in s.photos) p.caption],
        'startingPrices': <Map<String, dynamic>>[
          for (final StartingPrice p in s.startingPrices) p.toJson(),
        ],
        'healthcareDetails': s.healthcareDetails?.toJson(),
      };

  String _newKey() {
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < 16; i++) {
      b.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }
}
