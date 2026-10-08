import '../../domain/models/account.dart';
import '../local/key_value_store.dart';
import 'wire.dart';

/// On-device copy of the PUBLIC reference rows (cities, localities, service
/// catalog) so a cold start with no network can still show last-known data,
/// labelled stale (phases 077/078).
///
/// * Partitioned by [partition] (the build environment) and [version] (bump when
///   the stored shape changes): a mismatch reads as empty and the next write
///   replaces the old blob, so staging data can never appear in production.
/// * Raw public rows only. Owner profiles, phone numbers, tokens and
///   per-account data never pass through here; there is no API to put them in.
/// * Maximum stale window: [maxAge]. An older copy is ignored.
class PublicRefStore {
  PublicRefStore(
    this._kv, {
    required this.partition,
    DateTime Function()? now,
    this.maxAge = const Duration(days: 14),
  }) : _now = now ?? DateTime.now;

  static const int version = 1;

  final KeyValueStore _kv;
  final String partition;
  final Duration maxAge;
  final DateTime Function() _now;

  Map<String, dynamic> _entries() {
    final Map<String, dynamic>? blob = _kv.getJson(StorageKeys.publicRefCache);
    if (blob == null ||
        blob['partition'] != partition ||
        blob['v'] != version ||
        blob['entries'] is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }
    return blob['entries'] as Map<String, dynamic>;
  }

  /// The saved rows and when they were fetched, or null.
  ({DateTime at, Object? data})? read(String name) {
    final Object? entry = _entries()[name];
    if (entry is! Map<String, dynamic>) return null;
    final DateTime? at = DateTime.tryParse('${entry['at']}');
    if (at == null || _now().difference(at) > maxAge) return null;
    return (at: at, data: entry['data']);
  }

  Future<void> write(String name, DateTime at, Object? data) async {
    final Map<String, dynamic> entries = Map<String, dynamic>.of(_entries());
    entries[name] = <String, dynamic>{'at': at.toIso8601String(), 'data': data};
    await _kv.setJson(StorageKeys.publicRefCache, <String, dynamic>{
      'partition': partition,
      'v': version,
      'entries': entries,
    });
  }

  Future<void> clear() => _kv.remove(StorageKeys.publicRefCache);
}

/// In-memory cache of public reference data with an expiry.
///
/// [get] returns the cached value while fresh and otherwise reloads it, with
/// concurrent callers sharing one load. If a reload fails the last value is
/// still returned and [isStale] turns true so the UI can label it; with no
/// value at all the error propagates, unless a persisted copy exists (cold
/// start offline), which is served stale. Public data only: never cache owner
/// or private data here.
class RefCache<T> {
  RefCache(
    this._load, {
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 15),
    PublicRefStore? store,
    String? name,
    Object? Function(T)? encode,
    T Function(Object?)? decode,
  })  : _now = now ?? DateTime.now,
        _store = store,
        _name = name,
        _encode = encode,
        _decode = decode;

  final Future<T> Function() _load;
  final DateTime Function() _now;
  final Duration ttl;
  final PublicRefStore? _store;
  final String? _name;
  final Object? Function(T)? _encode;
  final T Function(Object?)? _decode;

  T? _value;
  DateTime? _at;
  Future<T>? _inflight;
  DateTime? _retryAt;
  bool isStale = false;

  /// The last loaded value, fresh or not.
  T? get value => _value;

  /// When [value] was fetched from the server (or saved on the device).
  DateTime? get asOf => _at;

  Future<T> get() {
    final T? v = _value;
    if (v != null) {
      final bool fresh = !isStale && _now().difference(_at!) < ttl;
      // After a failed refresh keep serving the stale copy for a short while
      // instead of making every screen wait out another set of retries.
      final bool backingOff = isStale && _now().isBefore(_retryAt!);
      if (fresh || backingOff) return Future<T>.value(v);
    }
    return _inflight ??= _reload().whenComplete(() => _inflight = null);
  }

  Future<T> _reload() async {
    try {
      final T fresh = await guardedRetry(_load);
      _value = fresh;
      _at = _now();
      isStale = false;
      _save(fresh);
      return fresh;
    } on RepositoryException {
      final T? old = _value ?? _restore();
      if (old == null) rethrow;
      isStale = true;
      _retryAt = _now().add(const Duration(seconds: 30));
      return old;
    }
  }

  void _save(T fresh) {
    final PublicRefStore? store = _store;
    if (store == null || _encode == null) return;
    // Best effort: a full or broken disk must not fail a successful load.
    store.write(_name!, _at!, _encode(fresh)).catchError((Object _) {});
  }

  T? _restore() {
    final PublicRefStore? store = _store;
    if (store == null || _decode == null) return null;
    final ({DateTime at, Object? data})? saved = store.read(_name!);
    if (saved == null) return null;
    try {
      final T value = _decode(saved.data);
      _value = value;
      _at = saved.at;
      return value;
    } on Object {
      return null; // a damaged copy is as good as none
    }
  }
}
