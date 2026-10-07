import '../local/key_value_store.dart';

/// Device-side resend pacing (phase 046).
///
/// This is a courtesy, not the control: the server owns the real per-number,
/// per-network and global limits (migration 20261007000024), so clearing app
/// data or restarting cannot buy extra messages. The cooldown is persisted
/// only as a timestamp (never a number or code) so a restart or backgrounding
/// does not reset the visible wait, and it uses the larger of the local wait
/// and any server-provided `retryAfter`.
class OtpCooldown {
  OtpCooldown({
    required KeyValueStore store,
    DateTime Function()? now,
    this.interval = const Duration(seconds: 60),
  })  : _store = store,
        _now = now ?? DateTime.now;

  static const String _key = 'auth.otpNextAllowedAt';

  final KeyValueStore _store;
  final DateTime Function() _now;
  final Duration interval;

  /// Time left before another code may be requested; zero when allowed.
  Duration remaining() {
    final DateTime? next = DateTime.tryParse(_store.getString(_key) ?? '');
    if (next == null) return Duration.zero;
    final Duration left = next.difference(_now());
    // A clock moved far backwards must not lock the user out for hours.
    if (left.isNegative) return Duration.zero;
    return left > const Duration(minutes: 15)
        ? const Duration(minutes: 15)
        : left;
  }

  Future<void> markSent() => _set(interval);

  /// Applies a server-provided wait (rate limit) if it is longer.
  Future<void> markRateLimited(Duration? retryAfter) {
    final Duration wait = retryAfter == null || retryAfter < interval
        ? interval
        : retryAfter;
    return _set(wait);
  }

  Future<void> clear() => _store.remove(_key);

  Future<void> _set(Duration wait) =>
      _store.setString(_key, _now().add(wait).toIso8601String());
}
