import '../models/enums.dart';
import '../models/moderation.dart';
import '../models/provider.dart';

/// Locally persisted provider onboarding draft.
///
/// Drafts survive app restarts so a provider can finish later. They are not
/// listings: nothing is public until the wizard is submitted and published.
abstract class ProviderDraftRepository {
  Future<ProviderDraft?> load();

  Future<void> save(ProviderDraft draft);

  Future<void> clear();
}

/// Saved (favourite) providers.
///
/// Stored on-device so guests can use the feature without an account, which is
/// a hard requirement: customers must never be forced to sign up.
abstract class SavedProviderRepository {
  Future<Set<String>> savedIds();

  Future<bool> isSaved(String providerId);

  Future<void> save(String providerId);

  Future<void> remove(String providerId);

  /// Toggles and returns the new state, for one-tap bookmark buttons.
  Future<bool> toggle(String providerId);

  /// Full profiles in the order they were saved, with already-unpublished
  /// listings filtered out.
  Future<List<ProviderProfile>> savedProfiles();
}

/// Consent records.
///
/// Kept separate from the profile because consent is an auditable history, not
/// a boolean flag.
abstract class ConsentRepository {
  Future<ConsentRecord> record({
    required String providerId,
    required ConsentKind kind,
    required bool granted,
    String? phoneE164,
    String wordingVersion,
  });

  Future<List<ConsentRecord>> forProvider(String providerId);

  /// Current state of every consent kind for a provider.
  Future<Map<ConsentKind, bool>> currentState(String providerId);
}

/// Verification records.
///
/// Two independent trails. The phone trail is written by a successful OTP; the
/// credentials trail can only be written by a review process. This separation is
/// what stops the UI from implying that OTP verified a qualification.
abstract class VerificationRepository {
  Future<VerificationRecord> recordPhoneVerification({
    required String providerId,
    required VerificationStatus status,
    required String method,
  });

  Future<List<VerificationRecord>> recordsFor(String providerId);

  Future<Map<VerificationKind, VerificationStatus>> currentStatus(
    String providerId,
  );

  /// Only a back-office review may call this. Not reachable from customer or
  /// provider UI in this build.
  Future<VerificationRecord> recordCredentialReview({
    required String providerId,
    required VerificationStatus status,
    required String reviewedBy,
    String? note,
  });
}

/// Professional credentials.
abstract class CredentialRepository {
  Future<List<CredentialRecord>> forProvider(String providerId);

  /// Saves provider-supplied professional details as *claimed* (pending
  /// review). Never generates credentials on the provider's behalf.
  Future<CredentialRecord> saveClaimed(CredentialRecord record);

  Future<void> remove(String credentialId);
}
