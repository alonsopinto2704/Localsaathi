import 'dart:async';

import 'package:localsaathi/data/supabase/auth_gateway.dart';

/// In-memory stand-in for GoTrue + PostgREST with the same observable rules
/// the real services have: single-use codes, wrong code == expired code,
/// identical `signInWithOtp` behaviour for new and existing numbers, rotating
/// sessions and phone-change conflicts. All numbers used with it are synthetic.
///
/// Codes live only inside this fake; tests fetch them with [codeFor] and never
/// print them.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  // ---- server state
  final Map<String, FakeUser> usersByPhone = <String, FakeUser>{};
  final Map<String, String> _codes = <String, String>{};
  int _seq = 0;

  // ---- knobs
  bool offline = false;
  bool revokeNextRefresh = false;
  bool sendRejected = false;
  Duration? rateLimitRetryAfter;
  bool rateLimitSends = false;
  Duration tokenLifetime = const Duration(hours: 1);
  Completer<void>? refreshGate;
  Completer<void>? verifyGate;
  Duration authenticatedAgo = Duration.zero;

  /// Fail the next delete call before the server does anything.
  bool failNextDelete = false;

  /// The server deletes the account but the response never arrives.
  bool loseNextDeleteResponse = false;

  // ---- observations (counts only: no secrets)
  int sendCount = 0;
  int verifyCalls = 0;
  int refreshCalls = 0;
  int signOutCalls = 0;
  final List<String> rpcCalls = <String>[];
  final Map<String, Map<String, dynamic>> deleteResults =
      <String, Map<String, dynamic>>{};
  final List<String> deleteKeys = <String>[];

  /// Overrides for RPCs; default handlers exist for the owner-state calls.
  final Map<String, Object? Function(Map<String, dynamic>?)> rpcHandlers =
      <String, Object? Function(Map<String, dynamic>?)>{};

  GatewaySession? _session;
  FakeUser? _user;

  String codeFor(String phone) => _codes[phone]!;

  FakeUser addUser(String phone, {Map<String, dynamic>? profile}) {
    final FakeUser user = FakeUser(
      id: 'user-${++_seq}-0000-0000-0000-000000000000',
      phone: phone,
      createdAt: _now(),
    )..profile = profile;
    usersByPhone[phone] = user;
    return user;
  }

  void setSessionTo(FakeUser user) {
    _user = user;
    _session = _newSession(user);
  }

  GatewaySession _newSession(FakeUser user) => GatewaySession(
        userId: user.id,
        phoneE164: user.phone,
        expiresAt: _now().add(tokenLifetime),
        authenticatedAt: _now().subtract(authenticatedAgo),
        signedInAt: _now(),
      );

  @override
  GatewaySession? get currentSession => _session;

  @override
  Future<GatewaySession?> restore() async {
    if (offline) throw const GatewayException(GatewayErrorKind.transient);
    final FakeUser? user = _user;
    if (user == null || !usersByPhone.containsKey(user.phone)) {
      _session = null;
      _user = null;
      return null;
    }
    return _session;
  }

  @override
  Future<void> sendOtp(String phoneE164) async {
    _checkOnline();
    if (rateLimitSends) {
      throw GatewayException(
        GatewayErrorKind.rateLimited,
        retryAfter: rateLimitRetryAfter,
      );
    }
    if (sendRejected) throw const GatewayException(GatewayErrorKind.sendRejected);
    sendCount++;
    // Same behaviour whether or not the user exists.
    _codes[phoneE164] = _nextCode();
  }

  @override
  Future<GatewaySession> verifyOtp(String phoneE164, String code) async {
    _checkOnline();
    verifyCalls++;
    if (verifyGate != null) await verifyGate!.future;
    final String? expected = _codes[phoneE164];
    if (expected == null || expected != code) {
      throw const GatewayException(GatewayErrorKind.invalidCode);
    }
    _codes.remove(phoneE164); // single use
    final FakeUser user = usersByPhone[phoneE164] ?? addUser(phoneE164);
    _user = user;
    _session = _newSession(user);
    return _session!;
  }

  @override
  Future<void> sendPhoneChangeOtp(String newPhoneE164) async {
    _checkOnline();
    if (_session == null) throw const GatewayException(GatewayErrorKind.sessionRevoked);
    if (usersByPhone.containsKey(newPhoneE164)) {
      throw const GatewayException(GatewayErrorKind.phoneConflict);
    }
    sendCount++;
    _codes[newPhoneE164] = _nextCode();
  }

  @override
  Future<GatewaySession> verifyPhoneChange(String newPhoneE164, String code) async {
    _checkOnline();
    verifyCalls++;
    final FakeUser? user = _user;
    if (user == null) throw const GatewayException(GatewayErrorKind.sessionRevoked);
    if (_codes[newPhoneE164] != code) {
      throw const GatewayException(GatewayErrorKind.invalidCode);
    }
    if (usersByPhone.containsKey(newPhoneE164)) {
      throw const GatewayException(GatewayErrorKind.phoneConflict);
    }
    _codes.remove(newPhoneE164);
    usersByPhone.remove(user.phone);
    user.phone = newPhoneE164;
    usersByPhone[newPhoneE164] = user;
    _session = _newSession(user);
    return _session!;
  }

  @override
  Future<GatewaySession> refresh() async {
    refreshCalls++;
    if (refreshGate != null) await refreshGate!.future;
    _checkOnline();
    if (revokeNextRefresh || _user == null) {
      revokeNextRefresh = false;
      throw const GatewayException(GatewayErrorKind.sessionRevoked);
    }
    _session = _newSession(_user!);
    return _session!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _session = null;
    _user = null;
  }

  @override
  Future<Object?> rpc(String function, [Map<String, dynamic>? params]) async {
    _checkOnline();
    rpcCalls.add(function);
    final Object? Function(Map<String, dynamic>?)? custom = rpcHandlers[function];
    if (custom != null) return custom(params);
    final FakeUser? user = _user;
    switch (function) {
      case 'my_account':
        if (user == null) return null;
        return <String, dynamic>{
          'id': user.id,
          // GoTrue form without '+', as the live function returned it before
          // migration 20261007000024.
          'phoneE164': user.phone.substring(1),
          'createdAt': user.createdAt.toIso8601String(),
          'profileId': user.profile?['id'],
          'phoneVerifiedAt': user.createdAt.toIso8601String(),
          'isSuspended': user.suspended,
        };
      case 'my_profile':
        return user?.profile;
      case 'request_sensitive_action':
        return <String, dynamic>{'ok': true};
    }
    throw const GatewayRpcException('not_found', 'unknown function');
  }

  @override
  Future<Map<String, dynamic>> deleteAccountRequest({
    required String idempotencyKey,
  }) async {
    _checkOnline();
    deleteKeys.add(idempotencyKey);
    if (failNextDelete) {
      failNextDelete = false;
      throw const GatewayException(GatewayErrorKind.transient);
    }
    final FakeUser? user = _user;
    // The user is gone: their token no longer authenticates.
    if (user == null || !usersByPhone.containsKey(user.phone)) {
      throw const GatewayException(GatewayErrorKind.sessionRevoked);
    }
    usersByPhone.remove(user.phone);
    final Map<String, dynamic> result = <String, dynamic>{
      'ok': true,
      'jobId': 'job-${deleteResults.length + 1}',
      'status': 'completed',
    };
    deleteResults[idempotencyKey] = result;
    if (loseNextDeleteResponse) {
      loseNextDeleteResponse = false;
      throw const GatewayException(GatewayErrorKind.transient);
    }
    return result;
  }

  void _checkOnline() {
    if (offline) throw const GatewayException(GatewayErrorKind.transient);
  }

  String _nextCode() => (100000 + (++_seq * 7919) % 900000).toString();
}

class FakeUser {
  FakeUser({required this.id, required this.phone, required this.createdAt});

  final String id;
  String phone;
  final DateTime createdAt;
  Map<String, dynamic>? profile;
  bool suspended = false;
}
