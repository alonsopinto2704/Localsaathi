import 'auth_gateway.dart';

/// The narrow read/RPC surface the live data repositories need (phase 061).
///
/// Like [AuthGateway], SDK types stop at the implementation; repositories and
/// tests only see plain JSON. Errors surface as [GatewayException] /
/// [GatewayRpcException] and are mapped once in `wire.dart`.
abstract class DataGateway {
  /// Calls a Postgres RPC (as the signed-in user, or anon) and returns its JSON.
  Future<Object?> rpc(String function, [Map<String, dynamic>? params]);

  /// Plain `SELECT *` of a public-read table, filtered by column equality and
  /// ordered ascending. Only the reference tables (locations, catalog) are
  /// readable this way; everything else is closed to clients.
  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    Map<String, String> eq = const <String, String>{},
    String? orderBy,
  });
}
