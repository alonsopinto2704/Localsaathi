import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';
import 'auth_gateway.dart';
import 'data_gateway.dart';
import 'secure_session_storage.dart';

/// Initialises the Supabase SDK for a live build. Call once from `main`, only
/// when [AuthConfig.hasLiveConfig]; sessions are kept in platform-backed
/// secure storage rather than the SDK's SharedPreferences default.
Future<SupabaseClient> initializeSupabase(
  AuthConfig config, {
  SecretStore? secrets,
}) async {
  final Supabase supabase = await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.anonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(secrets ?? PlatformSecretStore()),
      // We read nothing from deep links for auth; phone OTP needs none.
      detectSessionInUri: false,
    ),
  );
  return supabase.client;
}

/// The only file that touches Supabase auth types. Everything it returns is a
/// plain value from `auth_gateway.dart`; SDK exceptions are mapped to
/// [GatewayException] / [GatewayRpcException] so no screen, controller or log
/// line ever carries SDK objects, tokens or response bodies.
class SupabaseAuthGateway implements AuthGateway, DataGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  GatewaySession? get currentSession => _map(_auth.currentSession);

  @override
  Future<GatewaySession?> restore() async {
    final Session? stored = _auth.currentSession;
    if (stored == null) return null;
    // Validate against the server: a revoked or deleted user fails here.
    try {
      final UserResponse response = await _auth.getUser();
      if (response.user == null) {
        await _auth.signOut(scope: SignOutScope.local);
        return null;
      }
      return _map(_auth.currentSession);
    } on AuthException catch (error) {
      final GatewayException mapped = _mapAuth(error);
      if (mapped.kind == GatewayErrorKind.sessionRevoked) {
        await _auth.signOut(scope: SignOutScope.local);
        return null;
      }
      throw mapped;
    }
  }

  @override
  Future<void> sendOtp(String phoneE164) => _guard(
        () => _auth.signInWithOtp(phone: phoneE164, shouldCreateUser: true),
      );

  @override
  Future<GatewaySession> verifyOtp(String phoneE164, String code) => _guard(
        () async {
          final AuthResponse response = await _auth.verifyOTP(
            phone: phoneE164,
            token: code,
            type: OtpType.sms,
          );
          return _require(response.session);
        },
      );

  @override
  Future<void> sendPhoneChangeOtp(String newPhoneE164) =>
      _guard(() => _auth.updateUser(UserAttributes(phone: newPhoneE164)));

  @override
  Future<GatewaySession> verifyPhoneChange(String newPhoneE164, String code) =>
      _guard(() async {
        final AuthResponse response = await _auth.verifyOTP(
          phone: newPhoneE164,
          token: code,
          type: OtpType.phoneChange,
        );
        return _require(response.session ?? _auth.currentSession);
      });

  @override
  Future<GatewaySession> refresh() => _guard(() async {
        final AuthResponse response = await _auth.refreshSession();
        return _require(response.session);
      });

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (error) {
      throw _mapAuth(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    Map<String, String> eq = const <String, String>{},
    String? orderBy,
  }) async {
    try {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _client.from(table).select();
      for (final MapEntry<String, String> e in eq.entries) {
        query = query.eq(e.key, e.value);
      }
      return orderBy == null ? await query : await query.order(orderBy);
    } on PostgrestException catch (error) {
      throw _mapPostgrest(error);
    } on Object catch (error) {
      if (error is GatewayException || error is GatewayRpcException) rethrow;
      throw const GatewayException(GatewayErrorKind.transient);
    }
  }

  @override
  Future<Object?> rpc(String function, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc<Object?>(function, params: params);
    } on PostgrestException catch (error) {
      throw _mapPostgrest(error);
    } on AuthException catch (error) {
      throw _mapAuth(error);
    } on TimeoutException {
      throw const GatewayException(GatewayErrorKind.transient);
    } on Object catch (error) {
      if (error is GatewayException || error is GatewayRpcException) rethrow;
      throw const GatewayException(GatewayErrorKind.transient);
    }
  }

  @override
  Future<Map<String, dynamic>> deleteAccountRequest({
    required String idempotencyKey,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'delete-account',
        body: <String, dynamic>{'idempotencyKey': idempotencyKey},
      );
      final Object? data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw const GatewayException(GatewayErrorKind.unknown);
    } on FunctionException catch (error) {
      final Object? details = error.details;
      final String code = details is Map ? '${details['error']}' : '';
      if (error.status == 401 || code == 'not_authenticated') {
        throw const GatewayException(GatewayErrorKind.sessionRevoked);
      }
      if (code == 'reauth_required') {
        throw const GatewayException(GatewayErrorKind.reauthRequired);
      }
      if (error.status == 429) {
        throw const GatewayException(GatewayErrorKind.rateLimited);
      }
      throw const GatewayException(GatewayErrorKind.transient);
    }
  }

  // ------------------------------------------------------------ helpers
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on AuthException catch (error) {
      throw _mapAuth(error);
    } on TimeoutException {
      throw const GatewayException(GatewayErrorKind.transient);
    }
  }

  GatewaySession _require(Session? session) {
    final GatewaySession? mapped = _map(session);
    if (mapped == null) {
      throw const GatewayException(GatewayErrorKind.unknown);
    }
    return mapped;
  }

  GatewaySession? _map(Session? session) {
    if (session == null) return null;
    final Map<String, dynamic> claims =
        JwtClaims.decode(session.accessToken) ?? <String, dynamic>{};
    final int exp = (claims['exp'] as num?)?.toInt() ?? 0;
    final DateTime expiresAt = session.expiresAt != null
        ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    final String phone = session.user.phone ?? '';
    return GatewaySession(
      userId: session.user.id,
      phoneE164: phone.isEmpty || phone.startsWith('+') ? phone : '+$phone',
      expiresAt: expiresAt,
      authenticatedAt: lastAuthenticationAt(claims) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      assuranceLevel: (claims['aal'] as String?) ?? 'aal1',
      signedInAt: DateTime.tryParse(session.user.lastSignInAt ?? ''),
    );
  }

  /// Newest factor-proof time in the token's `amr` claim (`otp`, `sms`,
  /// `totp`). Refreshing a token keeps the old `amr` timestamps, so this is
  /// the right basis for "recent authentication", not `iat`.
  static DateTime? lastAuthenticationAt(Map<String, dynamic> claims) {
    final Object? amr = claims['amr'];
    if (amr is! List) return null;
    int newest = 0;
    for (final Object? entry in amr) {
      if (entry is Map && entry['method'] is String) {
        final String method = entry['method'] as String;
        final num? ts = entry['timestamp'] as num?;
        if (ts != null && <String>{'otp', 'sms', 'totp', 'phone'}.contains(method)) {
          if (ts.toInt() > newest) newest = ts.toInt();
        }
      }
    }
    return newest == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(newest * 1000, isUtc: true);
  }

  GatewayException _mapAuth(AuthException error) {
    final String code = error.code ?? '';
    final int? status = int.tryParse(error.statusCode ?? '');
    if (error is AuthRetryableFetchException) {
      return const GatewayException(GatewayErrorKind.transient);
    }
    if (error is AuthSessionMissingException) {
      return const GatewayException(GatewayErrorKind.sessionRevoked);
    }
    switch (code) {
      case 'otp_expired':
      case 'otp_disabled':
        // GoTrue reports a wrong and an expired code identically.
        return const GatewayException(GatewayErrorKind.invalidCode);
      case 'over_sms_send_rate_limit':
      case 'over_request_rate_limit':
        return const GatewayException(GatewayErrorKind.rateLimited);
      case 'sms_send_failed':
      case 'phone_provider_disabled':
      case 'validation_failed':
        return const GatewayException(GatewayErrorKind.sendRejected);
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
      case 'session_not_found':
      case 'session_expired':
      case 'user_not_found':
      case 'bad_jwt':
        return const GatewayException(GatewayErrorKind.sessionRevoked);
      case 'reauthentication_needed':
      case 'reauthentication_not_valid':
        return const GatewayException(GatewayErrorKind.reauthRequired);
      case 'phone_exists':
        return const GatewayException(GatewayErrorKind.phoneConflict);
      case 'user_banned':
        return const GatewayException(GatewayErrorKind.forbidden);
    }
    if (status == 429) return const GatewayException(GatewayErrorKind.rateLimited);
    if (status != null && status >= 500) {
      return const GatewayException(GatewayErrorKind.transient);
    }
    if (status == 401) return const GatewayException(GatewayErrorKind.sessionRevoked);
    return const GatewayException(GatewayErrorKind.unknown);
  }

  Object _mapPostgrest(PostgrestException error) {
    final String message = error.message;
    final RegExpMatch? match = RegExp(r'^([a-z_]+):\s*(.*)$', dotAll: true)
        .firstMatch(message);
    if (match != null) {
      return GatewayRpcException(match.group(1)!, match.group(2) ?? '');
    }
    final String code = error.code ?? '';
    if (code == 'PGRST301' || code == 'PGRST303') {
      return const GatewayException(GatewayErrorKind.sessionRevoked);
    }
    if (code == '42501') {
      return const GatewayException(GatewayErrorKind.forbidden);
    }
    return const GatewayException(GatewayErrorKind.transient);
  }
}
