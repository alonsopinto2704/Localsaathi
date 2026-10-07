import '../../domain/models/account.dart';
import '../../domain/models/provider.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_config.dart';

/// Chooses the identity implementation for a build (phase 041).
///
/// * `demo`  -> the simulated repository. The only environment allowed to use
///   it, because it accepts a fixed code.
/// * `staging` / `production` -> the live repository **only if** the Supabase
///   configuration is usable; otherwise a [FailClosedAuthRepository]. A
///   production build can therefore never fall back to the simulation, even
///   with a missing or malformed configuration.
///
/// Guest discovery does not depend on this choice.
ProviderAuthRepository selectAuthRepository({
  required AuthConfig config,
  required ProviderAuthRepository Function() demo,
  required ProviderAuthRepository Function() live,
}) {
  if (config.isDemo) return demo();
  final String? problem = config.problem;
  if (problem != null) return FailClosedAuthRepository(problem);
  return live();
}

/// Used when production authentication is not configured. Everyone stays a
/// guest; every sign-in attempt fails with the generic "could not send" error.
class FailClosedAuthRepository implements ProviderAuthRepository {
  const FailClosedAuthRepository(this.reason);

  /// Developer-facing, contains no secret values.
  final String reason;

  static const RepositoryException _denied =
      RepositoryException(RepositoryErrorCode.notAuthenticated);

  @override
  Future<ProviderSession?> restoreSession() async => null;

  @override
  Future<OtpChallengeResult> requestOtp(String rawPhone) async =>
      OtpChallengeResult.failure(PhoneInputError.sendFailed);

  @override
  Future<PhoneVerificationResult> verifyOtp({
    required String challengeId,
    required String code,
  }) =>
      Future<PhoneVerificationResult>.error(
        const OtpException(OtpFailure.unknown),
      );

  @override
  Future<ProviderAccount?> currentAccount() async => null;

  @override
  Future<ProviderProfile?> currentProfile() async => null;

  @override
  Future<ProviderProfile> registerProfile({
    required RegistrationSubmission submission,
  }) =>
      Future<ProviderProfile>.error(_denied);

  @override
  Future<OtpChallengeResult> requestPhoneNumberChange(String rawPhone) async =>
      OtpChallengeResult.failure(PhoneInputError.sendFailed);

  @override
  Future<ProviderAccount> confirmPhoneNumberChange({
    required String challengeId,
    required String code,
  }) =>
      Future<ProviderAccount>.error(_denied);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() => Future<void>.error(_denied);
}
