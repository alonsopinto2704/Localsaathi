import 'dart:async';

import 'auth_gateway.dart';

/// Keeps the access token usable without refresh storms (phase 050).
///
/// * **Single flight:** any number of concurrent callers share one network
///   refresh.
/// * **Bounded retries:** only transient failures are retried, at most
///   [maxAttempts] times with growing delay; a revoked session is final.
/// * **No fallback to guest:** a revoked session calls [onRevoked] and throws
///   `sessionRevoked`; callers must stop the protected write and ask the user
///   to sign in again (their draft is kept by the caller).
/// * **Generation guard:** [invalidate] (sign-out, account switch) makes an
///   in-flight refresh's result unusable, so a late response can never revive
///   a session the user just ended.
class SessionRefresher {
  SessionRefresher({
    required AuthGateway gateway,
    DateTime Function()? now,
    this.skew = const Duration(seconds: 60),
    this.maxAttempts = 3,
    Future<void> Function(Duration)? sleep,
    this.onRevoked,
  })  : _gateway = gateway,
        _now = now ?? DateTime.now,
        _sleep = sleep ?? (Future<void>.delayed);

  final AuthGateway _gateway;
  final DateTime Function() _now;
  final Duration skew;
  final int maxAttempts;
  final Future<void> Function(Duration) _sleep;

  /// Called once per revocation, after local credentials were cleared.
  final void Function()? onRevoked;

  Future<GatewaySession>? _inFlight;
  int _generation = 0;

  /// Network refreshes started (for tests and aggregate failure counts only).
  int refreshCount = 0;

  /// Returns a session that will not expire within [skew], refreshing if
  /// needed. Throws [GatewayException] (`sessionRevoked` when there is no
  /// session, `transient` when offline).
  Future<GatewaySession> ensureFresh() {
    final GatewaySession? current = _gateway.currentSession;
    if (current == null) {
      return Future<GatewaySession>.error(
        const GatewayException(GatewayErrorKind.sessionRevoked),
      );
    }
    if (!current.isExpiredAt(_now(), skew: skew)) {
      return Future<GatewaySession>.value(current);
    }
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  /// Ends any in-flight refresh's authority (call on sign-out/account change).
  void invalidate() => _generation++;

  Future<GatewaySession> _refresh() async {
    final int generation = _generation;
    GatewayException? last;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await _sleep(Duration(seconds: 1 << (attempt - 1)));
      }
      if (generation != _generation) {
        throw const GatewayException(GatewayErrorKind.sessionRevoked);
      }
      refreshCount++;
      GatewaySession? session;
      try {
        session = await _gateway.refresh();
      } on GatewayException catch (error) {
        if (error.kind == GatewayErrorKind.sessionRevoked) {
          _generation++;
          await _gateway.signOut();
          onRevoked?.call();
          rethrow;
        }
        last = error;
        if (error.kind != GatewayErrorKind.transient &&
            error.kind != GatewayErrorKind.rateLimited) {
          rethrow;
        }
      }
      if (session != null) {
        if (generation != _generation) {
          // The user ended this session while the refresh was in flight.
          await _gateway.signOut();
          throw const GatewayException(GatewayErrorKind.sessionRevoked);
        }
        return session;
      }
    }
    throw last ?? const GatewayException(GatewayErrorKind.transient);
  }
}
