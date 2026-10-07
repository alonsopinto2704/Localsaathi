/// The narrow surface of the identity backend that
/// `SupabaseProviderAuthRepository` needs.
///
/// SDK types stop here: screens, controllers and the repository only see these
/// plain types, and tests substitute a fake. Nothing in this file may log a
/// code, a token or a full number.
library;

/// An authenticated session as the app understands it.
class GatewaySession {
  const GatewaySession({
    required this.userId,
    required this.phoneE164,
    required this.expiresAt,
    required this.authenticatedAt,
    this.assuranceLevel = 'aal1',
    this.signedInAt,
  });

  final String userId;

  /// E.164 with a leading '+', or empty if the token carries no phone.
  final String phoneE164;

  /// When the access token stops being accepted.
  final DateTime expiresAt;

  /// When the user last proved control of a factor (OTP/TOTP), taken from the
  /// token's `amr` claim. A refresh does NOT move this; only a fresh OTP does.
  /// This is what "recent authentication" (phase 055) is measured against.
  final DateTime authenticatedAt;

  /// `aal1` (one factor) or `aal2` (MFA).
  final String assuranceLevel;

  final DateTime? signedInAt;

  bool isExpiredAt(DateTime now, {Duration skew = Duration.zero}) =>
      !now.add(skew).isBefore(expiresAt);

  /// Never prints the token (there is none here) or the number.
  @override
  String toString() => 'GatewaySession(user: ${userId.length > 8 ? userId.substring(0, 8) : userId}…)';
}

enum GatewayErrorKind {
  /// Wrong code, or a code that expired (GoTrue does not tell them apart).
  invalidCode,

  /// The server rate-limited this phone, network or project.
  rateLimited,

  /// The SMS could not be sent or the number is not allowed to receive one.
  sendRejected,

  /// The refresh token was revoked or the session no longer exists.
  sessionRevoked,

  /// The request needs a more recent authentication ("reauth_required").
  reauthRequired,

  /// The new phone number already belongs to another account.
  phoneConflict,

  /// The caller may not do this (RLS / role / suspended).
  forbidden,

  /// Connectivity or a 5xx: the outcome is unknown. Never infer success.
  transient,

  unknown,
}

class GatewayException implements Exception {
  const GatewayException(this.kind, {this.retryAfter});

  final GatewayErrorKind kind;

  /// Server-provided wait for [GatewayErrorKind.rateLimited], when known.
  final Duration? retryAfter;

  @override
  String toString() => 'GatewayException(${kind.name})';
}

/// A Postgres/PostgREST error raised by one of our RPCs. [prefix] is the
/// stable machine-readable code before the colon (see backend-contract.md
/// section 11), e.g. `not_owner`; [message] is the human text after it.
class GatewayRpcException implements Exception {
  const GatewayRpcException(this.prefix, [this.message = '']);

  final String prefix;
  final String message;

  @override
  String toString() => 'GatewayRpcException($prefix)';
}

abstract class AuthGateway {
  /// The session held in memory, or null. Synchronous: it is whatever the
  /// last verify/refresh/restore produced.
  GatewaySession? get currentSession;

  /// Loads a persisted session and validates it with the server (refreshing it
  /// if needed). Returns null when there is none or it was revoked.
  Future<GatewaySession?> restore();

  Future<void> sendOtp(String phoneE164);

  Future<GatewaySession> verifyOtp(String phoneE164, String code);

  /// Starts a number change: the code goes to the NEW number.
  Future<void> sendPhoneChangeOtp(String newPhoneE164);

  Future<GatewaySession> verifyPhoneChange(String newPhoneE164, String code);

  /// One network refresh. Callers must go through `SessionRefresher`, which
  /// de-duplicates concurrent calls.
  Future<GatewaySession> refresh();

  Future<void> signOut();

  /// Calls a Postgres RPC as the signed-in user and returns the JSON result.
  Future<Object?> rpc(String function, [Map<String, dynamic>? params]);

  /// Calls the `delete-account` Edge Function and returns its JSON body.
  Future<Map<String, dynamic>> deleteAccountRequest({
    required String idempotencyKey,
  });
}
