import '../../core/config/app_config.dart';
import '../../core/utils/phone_number.dart';
import '../../domain/models/account.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/moderation.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/auth_repository.dart';
import 'mock_data_store.dart';

/// Mock provider authentication with a **development-only OTP simulation**.
///
/// What this class gets right, because these are the rules the backend must
/// also enforce:
///
/// * the normalised E.164 number is the only identity key, so the many ways of
///   typing the same number collapse to one account;
/// * uniqueness is checked at the point of write against the store's index, the
///   mock equivalent of a `UNIQUE` constraint — not merely in the UI;
/// * requesting a code **never reveals** whether a number already has a
///   profile, so the endpoint cannot be used to enumerate registered numbers;
/// * verification is the gate: only after a correct code does
///   [PhoneVerificationResult.existingProfileId] become non-null, and only then
///   is a session issued. Merely typing someone's number grants nothing;
/// * a phone-number change needs an active session, a code sent to the *new*
///   number, and a fresh uniqueness check.
///
/// What is deliberately fake, and must be replaced before production:
/// the code itself, its storage, and the absence of rate limiting. See the
/// README section "Before production".
class MockProviderAuthRepository implements ProviderAuthRepository {
  MockProviderAuthRepository({
    required MockDataStore store,
    DateTime? now,
  })  : _store = store,
        _now = now ?? DateTime.now();

  final MockDataStore _store;
  final DateTime _now;

  /// Challenges created for the "change my number" flow, mapped to the new
  /// number they were issued for.
  final Map<String, String> _phoneChangeChallenges = <String, String>{};

  @override
  Future<ProviderSession?> restoreSession() async => _store.session;

  @override
  Future<OtpChallengeResult> requestOtp(String rawPhone) async {
    final NormalizedPhone? phone = PhoneUtils.tryNormalize(rawPhone);
    if (phone == null) {
      if (rawPhone.trim().isEmpty) {
        return OtpChallengeResult.failure(PhoneInputError.empty);
      }
      if (PhoneUtils.looksLikeInternational(rawPhone) &&
          !PhoneUtils.digitsOf(rawPhone).startsWith('91')) {
        return OtpChallengeResult.failure(PhoneInputError.unsupportedRegion);
      }
      return OtpChallengeResult.failure(PhoneInputError.invalidFormat);
    }

    // Note what is NOT here: no existence check, no branch on whether a profile
    // already exists. The response is identical either way.
    final OtpChallenge challenge = _issueChallenge(phone.e164);
    return OtpChallengeResult.success(challenge);
  }

  @override
  Future<PhoneVerificationResult> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    final OtpChallenge challenge = _consumeChallenge(challengeId, code);
    final String e164 = challenge.phoneE164;

    // Verification succeeded: now, and only now, it is safe to reveal whether
    // this number already owns a profile.
    final ProviderProfile? existingProfile = _store.profileForPhone(e164);
    ProviderAccount account = _store.accountForPhone(e164) ??
        ProviderAccount(
          id: _store.newId('account'),
          phoneE164: e164,
          createdAt: _now,
        );

    account = account.copyWith(
      phoneVerifiedAt: _now,
      lastSignedInAt: _now,
      profileId: existingProfile?.id ?? account.profileId,
    );
    _store.accountsById[account.id] = account;
    _store.accountIdByPhone[e164] = account.id;
    _store.phonesByE164[e164] = PhoneIdentity(
      e164: e164,
      createdAt: _store.phonesByE164[e164]?.createdAt ?? _now,
      lastVerifiedAt: _now,
      verified: true,
    );

    final ProviderSession session = ProviderSession(
      accountId: account.id,
      phoneE164: e164,
      signedInAt: _now,
      profileId: account.profileId,
    );
    _store.session = session;

    await _store.persistAccounts();
    await _store.persistSession();

    if (existingProfile != null) {
      await _recordPhoneVerification(existingProfile.id);
    }

    return PhoneVerificationResult(
      session: session,
      isNewAccount: existingProfile == null,
      phoneVerified: true,
      existingProfileId: existingProfile?.id,
      profile: existingProfile,
    );
  }

  @override
  Future<ProviderAccount?> currentAccount() async {
    final ProviderSession? session = _store.session;
    if (session == null) return null;
    return _store.accountsById[session.accountId];
  }

  @override
  Future<ProviderProfile?> currentProfile() async {
    final ProviderSession? session = _store.session;
    if (session == null) return null;
    final String? profileId = session.profileId;
    if (profileId == null) return null;
    return _store.profilesById[profileId];
  }

  @override
  Future<ProviderProfile> registerProfile({
    required RegistrationSubmission submission,
  }) async {
    if (_store.session == null ||
        _store.session!.phoneE164 != submission.phoneE164) {
      throw const RepositoryException(RepositoryErrorCode.notAuthenticated);
    }
    // Final uniqueness gate before the write, mirroring the unique index.
    if (_store.profileIdByPhone.containsKey(submission.phoneE164)) {
      throw DuplicatePhoneNumberException(submission.phoneE164);
    }

    final String profileId = _store.newId('provider');
    final ProviderProfile profile = ProviderProfile(
      id: profileId,
      phoneE164: submission.phoneE164,
      displayName: submission.displayName.trim(),
      baseCityId: submission.baseCityId,
      baseLocalityId: submission.baseLocalityId,
      status: ListingStatus.draft,
      createdAt: _now,
      updatedAt: _now,
      categoryIds: submission.categoryIds,
      serviceAreas: <ProviderServiceArea>[
        for (final String localityId in submission.serviceAreaIds)
          ProviderServiceArea(
            cityId: submission.baseCityId,
            localityId: localityId,
            isPrimary: localityId == submission.baseLocalityId,
          ),
      ],
      description: (submission.description ?? '').trim().isEmpty
          ? null
          : submission.description!.trim(),
      languages: submission.languages,
      workingHours: submission.workingHours,
      photos: submission.photos,
      startingPrices: submission.startingPrices,
      healthcareDetails: submission.healthcareDetails,
      homeVisits: submission.homeVisits,
      availability: AvailabilityStatus.available,
      whatsappEnabled:
          submission.whatsappEnabled && submission.phoneDisplayConsented,
      phoneDisplayConsented: submission.phoneDisplayConsented,
      verification: const <VerificationKind, VerificationStatus>{
        VerificationKind.phone: VerificationStatus.approved,
      },
      isDemoProfile: false,
    );

    _store.profilesById[profileId] = profile;
    _store.profileIdByPhone[submission.phoneE164] = profileId;

    final ProviderAccount? account =
        _store.accountForPhone(submission.phoneE164);
    if (account != null) {
      _store.accountsById[account.id] =
          account.copyWith(profileId: profileId, lastSignedInAt: _now);
    }
    _store.session = _store.session!.copyWith(profileId: profileId);

    await _recordConsents(profile, submission.termsAcceptedVersion);
    await _recordPhoneVerification(profileId);

    await _store.persistProfiles();
    await _store.persistAccounts();
    await _store.persistSession();
    return profile;
  }

  @override
  Future<OtpChallengeResult> requestPhoneNumberChange(String rawPhone) async {
    final ProviderSession? session = _store.session;
    if (session == null) {
      return OtpChallengeResult.failure(PhoneInputError.sendFailed);
    }
    final NormalizedPhone? phone = PhoneUtils.tryNormalize(rawPhone);
    if (phone == null) {
      return OtpChallengeResult.failure(PhoneInputError.invalidFormat);
    }
    // Changing to the number you already use is a no-op, not an error.
    if (phone.e164 == session.phoneE164) {
      return OtpChallengeResult.failure(PhoneInputError.invalidFormat);
    }
    final OtpChallenge challenge = _issueChallenge(phone.e164);
    _phoneChangeChallenges[challenge.id] = phone.e164;
    return OtpChallengeResult.success(challenge);
  }

  @override
  Future<ProviderAccount> confirmPhoneNumberChange({
    required String challengeId,
    required String code,
  }) async {
    final ProviderSession? session = _store.session;
    if (session == null) {
      throw const RepositoryException(RepositoryErrorCode.notAuthenticated);
    }
    final String? newE164 = _phoneChangeChallenges[challengeId];
    if (newE164 == null) {
      throw const OtpException(OtpFailure.unknown);
    }
    final OtpChallenge challenge = _consumeChallenge(challengeId, code);

    // Uniqueness check on the new number, after verification so we still do not
    // leak which numbers are registered to an unauthenticated caller.
    final String? existingOwner = _store.profileIdByPhone[challenge.phoneE164];
    if (existingOwner != null && existingOwner != session.profileId) {
      throw DuplicatePhoneNumberException(challenge.phoneE164);
    }

    final String oldE164 = session.phoneE164;
    final String? profileId = session.profileId;

    final ProviderIdentityMove move = ProviderIdentityMove(
      fromE164: oldE164,
      toE164: newE164,
      profileId: profileId,
      accountId: session.accountId,
    );
    await _applyIdentityMove(move);

    _phoneChangeChallenges.remove(challengeId);
    final ProviderAccount? account = _store.accountsById[session.accountId];
    if (account == null) {
      throw const RepositoryException(RepositoryErrorCode.notFound);
    }
    return account;
  }

  @override
  Future<void> signOut() async {
    _store.session = null;
    await _store.persistSession();
  }

  @override
  Future<void> deleteAccount() async {
    final ProviderSession? session = _store.session;
    if (session == null) return;

    // Deleting the account removes the listing and releases the number, which
    // is what "delete my account" promises the provider.
    final String? profileId = session.profileId;
    if (profileId != null) {
      _store.profilesById.remove(profileId);
      _store.profileIdByPhone.remove(session.phoneE164);
      _store.consents.removeWhere((ConsentRecord c) => c.providerId == profileId);
      _store.verificationRecords
          .removeWhere((VerificationRecord v) => v.providerId == profileId);
      _store.engagementEvents
          .removeWhere((EngagementEvent e) => e.providerId == profileId);
    }
    _store.accountsById.remove(session.accountId);
    _store.accountIdByPhone.remove(session.phoneE164);
    _store.phonesByE164.remove(session.phoneE164);
    _store.session = null;

    await _store.persistProfiles();
    await _store.persistAccounts();
    await _store.persistConsents();
    await _store.persistVerification();
    await _store.persistEngagement();
    await _store.persistSession();
  }

  // ------------------------------------------------------------- internals
  OtpChallenge _issueChallenge(String e164) {
    const Duration validity = AppConfig.developmentOtpValidity;
    final OtpChallenge challenge = OtpChallenge(
      id: _store.newId('otp'),
      phoneE164: e164,
      issuedAt: _now,
      expiresAt: _now.add(validity),
      simulatedCode: AppConfig.useDevelopmentOtpSimulation
          ? AppConfig.developmentOtpCode
          : _store.newSimulatedCode(),
    );
    _store.pendingChallenges[challenge.id] = challenge;
    return challenge;
  }

  /// Validates and burns a challenge, or throws [OtpException].
  OtpChallenge _consumeChallenge(String challengeId, String code) {
    final OtpChallenge? challenge = _store.pendingChallenges[challengeId];
    if (challenge == null) throw const OtpException(OtpFailure.unknown);

    if (challenge.isExpiredAt(_now)) {
      _store.pendingChallenges.remove(challengeId);
      throw const OtpException(OtpFailure.expired);
    }
    if (challenge.attempts >= AppConfig.developmentOtpMaxAttempts) {
      _store.pendingChallenges.remove(challengeId);
      throw const OtpException(OtpFailure.attemptsExceeded);
    }
    if (challenge.simulatedCode != code.trim()) {
      final OtpChallenge updated =
          challenge.copyWith(attempts: challenge.attempts + 1);
      _store.pendingChallenges[challengeId] = updated;
      if (updated.attempts >= AppConfig.developmentOtpMaxAttempts) {
        _store.pendingChallenges.remove(challengeId);
        throw const OtpException(OtpFailure.attemptsExceeded);
      }
      throw const OtpException(OtpFailure.invalid);
    }

    final OtpChallenge consumed = challenge.copyWith(consumedAt: _now);
    _store.pendingChallenges.remove(challengeId);
    return consumed;
  }

  Future<void> _recordConsents(
    ProviderProfile profile,
    String? termsVersion,
  ) async {
    final List<ConsentRecord> records = <ConsentRecord>[
      if (termsVersion != null)
        ConsentRecord(
          id: _store.newId('consent'),
          providerId: profile.id,
          kind: ConsentKind.termsAccepted,
          granted: true,
          recordedAt: _now,
          wordingVersion: termsVersion,
          phoneE164: profile.phoneE164,
        ),
      ConsentRecord(
        id: _store.newId('consent'),
        providerId: profile.id,
        kind: ConsentKind.publicProfile,
        granted: true,
        recordedAt: _now,
        wordingVersion: MockDataStore.consentWordingVersion,
        phoneE164: profile.phoneE164,
      ),
      ConsentRecord(
        id: _store.newId('consent'),
        providerId: profile.id,
        kind: ConsentKind.displayPhoneNumber,
        granted: profile.phoneDisplayConsented,
        recordedAt: _now,
        wordingVersion: MockDataStore.consentWordingVersion,
        phoneE164: profile.phoneE164,
      ),
      ConsentRecord(
        id: _store.newId('consent'),
        providerId: profile.id,
        kind: ConsentKind.whatsappContact,
        granted: profile.whatsappEnabled,
        recordedAt: _now,
        wordingVersion: MockDataStore.consentWordingVersion,
        phoneE164: profile.phoneE164,
      ),
    ];
    _store.consents.addAll(records);
    await _store.persistConsents();
  }

  Future<void> _recordPhoneVerification(String profileId) async {
    _store.verificationRecords.add(
      VerificationRecord(
        id: _store.newId('ver'),
        providerId: profileId,
        kind: VerificationKind.phone,
        status: VerificationStatus.approved,
        createdAt: _now,
        method: AppConfig.useDevelopmentOtpSimulation
            ? 'otp_simulated'
            : 'otp_sms',
        note: 'Phone control confirmed by one-time code. This says nothing '
            'about professional qualifications.',
      ),
    );
    await _store.persistVerification();
  }

  /// Moves the account, phone identity and profile from the old number to the
  /// verified new one.
  ///
  /// All three must move together, otherwise a number could be released while
  /// its profile still points at it, which is exactly the inconsistency a
  /// backend transaction exists to prevent.
  Future<void> _applyIdentityMove(ProviderIdentityMove move) async {
    final ProviderAccount? account = _store.accountsById[move.accountId];
    if (account == null) return;

    _store.accountIdByPhone.remove(move.fromE164);
    _store.accountIdByPhone[move.toE164] = account.id;
    _store.accountsById[account.id] = account.copyWith(
      phoneE164: move.toE164,
      phoneVerifiedAt: _now,
      lastSignedInAt: _now,
    );

    _store.phonesByE164.remove(move.fromE164);
    _store.phonesByE164[move.toE164] = PhoneIdentity(
      e164: move.toE164,
      createdAt: _store.phonesByE164[move.fromE164]?.createdAt ?? _now,
      lastVerifiedAt: _now,
      verified: true,
    );

    final String? profileId = move.profileId;
    if (profileId != null) {
      final ProviderProfile? profile = _store.profilesById[profileId];
      if (profile != null) {
        _store.profileIdByPhone.remove(move.fromE164);
        _store.profileIdByPhone[move.toE164] = profileId;
        _store.profilesById[profileId] = ProviderProfile(
          id: profile.id,
          phoneE164: move.toE164,
          displayName: profile.displayName,
          baseCityId: profile.baseCityId,
          baseLocalityId: profile.baseLocalityId,
          status: profile.status,
          createdAt: profile.createdAt,
          updatedAt: _now,
          categoryIds: profile.categoryIds,
          serviceAreas: profile.serviceAreas,
          description: profile.description,
          languages: profile.languages,
          workingHours: profile.workingHours,
          photos: profile.photos,
          startingPrices: profile.startingPrices,
          healthcareDetails: profile.healthcareDetails,
          homeVisits: profile.homeVisits,
          availability: profile.availability,
          whatsappEnabled: profile.whatsappEnabled,
          phoneDisplayConsented: profile.phoneDisplayConsented,
          verification: profile.verification,
          isDemoProfile: profile.isDemoProfile,
          pinCodes: profile.pinCodes,
        );
        await _recordPhoneVerification(profileId);
      }
    }

    _store.session = ProviderSession(
      accountId: account.id,
      phoneE164: move.toE164,
      signedInAt: _store.session?.signedInAt ?? _now,
      profileId: move.profileId,
    );

    await _store.persistAccounts();
    await _store.persistProfiles();
    await _store.persistSession();
  }
}

/// Internal description of a phone-number change, so the mutation is explicit
/// and testable.
class ProviderIdentityMove {
  const ProviderIdentityMove({
    required this.fromE164,
    required this.toE164,
    required this.accountId,
    this.profileId,
  });

  final String fromE164;
  final String toE164;
  final String accountId;
  final String? profileId;
}
