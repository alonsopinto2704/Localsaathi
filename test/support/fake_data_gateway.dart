import 'package:localsaathi/data/supabase/auth_gateway.dart';
import 'package:localsaathi/data/supabase/data_gateway.dart';

/// In-memory stand-in for PostgREST: public-read tables and RPC handlers. No
/// network. All data in tests is synthetic.
class FakeDataGateway implements DataGateway {
  final Map<String, List<Map<String, dynamic>>> tables =
      <String, List<Map<String, dynamic>>>{};

  /// A handler may return a value or a Future (to model slow responses).
  final Map<String, Object? Function(Map<String, dynamic>?)> handlers =
      <String, Object? Function(Map<String, dynamic>?)>{};

  final List<String> calls = <String>[];
  final List<Map<String, dynamic>?> rpcParams = <Map<String, dynamic>?>[];

  /// While set, every call throws it (e.g. a transient [GatewayException]).
  Object? failure;

  int get selectCount => calls.where((String c) => c.startsWith('select:')).length;

  @override
  Future<Object?> rpc(String function, [Map<String, dynamic>? params]) async {
    calls.add('rpc:$function');
    rpcParams.add(params);
    if (failure != null) throw failure!;
    final Object? Function(Map<String, dynamic>?)? h = handlers[function];
    if (h == null) throw const GatewayRpcException('not_found', 'unknown function');
    return h(params);
  }

  @override
  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    Map<String, String> eq = const <String, String>{},
    String? orderBy,
  }) async {
    calls.add('select:$table');
    if (failure != null) throw failure!;
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
      for (final Map<String, dynamic> r in tables[table] ?? <Map<String, dynamic>>[])
        if (eq.entries.every((MapEntry<String, String> e) => r[e.key] == e.value))
          Map<String, dynamic>.of(r),
    ];
    if (orderBy != null) {
      rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
          '${a[orderBy]}'.compareTo('${b[orderBy]}'),);
    }
    return rows;
  }
}

const String kProviderId = '0f3c1a2e-7b44-4d0a-9a51-6c2d0e5b1a03';
const String kOtherId = '1a2b3c4d-7b44-4d0a-9a51-6c2d0e5b1a99';

/// A minimal valid public-shape profile (camelCase, as the RPCs return it).
Map<String, dynamic> wireProfile({
  String id = kProviderId,
  String name = 'Synthetic Plumber',
  String status = 'published',
  Map<String, dynamic>? extra,
}) =>
    <String, dynamic>{
      'id': id,
      'phoneE164': '+919800000001',
      'displayName': name,
      'baseCityId': 'city-a',
      'baseLocalityId': 'loc-a1',
      'status': status,
      'createdAt': '2026-08-20T09:00:00+00:00',
      'updatedAt': '2026-09-25T12:45:00+00:00',
      'categoryIds': <String>['plumbing'],
      'serviceAreas': <Map<String, dynamic>>[
        <String, dynamic>{'cityId': 'city-a', 'localityId': 'loc-a1', 'isPrimary': true},
      ],
      'phoneDisplayConsented': true,
      'whatsappEnabled': false,
      ...?extra,
    };

/// Reference rows as the public tables return them (snake_case).
void seedReference(FakeDataGateway g, {String cityAStatus = 'active'}) {
  g.tables['countries'] = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'in', 'name': 'India', 'iso_code': 'IN', 'dial_code': '91', 'is_active': true},
  ];
  g.tables['state_regions'] = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'st-a', 'country_id': 'in', 'name': 'State A', 'is_union_territory': false, 'is_active': true},
  ];
  g.tables['cities'] = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'city-a', 'state_id': 'st-a', 'name': 'Alpha', 'launch_status': cityAStatus, 'aliases': <String>['A-town'], 'is_metro': true},
    <String, dynamic>{'id': 'city-b', 'state_id': 'st-a', 'name': 'Beta', 'launch_status': 'coming_soon', 'aliases': <String>[], 'is_metro': false},
    <String, dynamic>{'id': 'city-c', 'state_id': 'st-a', 'name': 'Gamma', 'launch_status': 'something_new', 'aliases': <String>[], 'is_metro': false},
  ];
  g.tables['localities'] = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'loc-a1', 'city_id': 'city-a', 'name': 'Alpha One', 'pin_code': '400001', 'is_popular': false},
    <String, dynamic>{'id': 'loc-a2', 'city_id': 'city-a', 'name': 'Alpha Two', 'pin_code': null, 'is_popular': true},
  ];
}
