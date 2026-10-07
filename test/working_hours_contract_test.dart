import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/domain/models/provider.dart';

// Phase 031: the same boundary fixtures drive the SQL open-now filter
// (backend/scripts/verify-db.mjs), so app labels and search agree.
void main() {
  final Map<String, dynamic> fixture = jsonDecode(
    File('docs/contracts/fixtures/working-hours.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final dynamic raw in fixture['cases'] as List<dynamic>) {
    final Map<String, dynamic> c = raw as Map<String, dynamic>;
    test(c['name'] as String, () {
      final Map<int, DayHours> given = <int, DayHours>{
        for (final dynamic d in c['days'] as List<dynamic>)
          (d as Map<String, dynamic>)['weekday'] as int: DayHours(
            weekday: d['weekday'] as int,
            openMinutes: d['open'] as int,
            closeMinutes: d['close'] as int,
          ),
      };
      final WorkingHours hours = WorkingHours(<DayHours>[
        for (int day = 1; day <= 7; day++) given[day] ?? DayHours.closed(day),
      ]);
      final Map<String, dynamic> at = c['at'] as Map<String, dynamic>;
      // 2026-01-05 is a Monday; weekday N is 2026-01-(4+N).
      final int minutes = at['minutes'] as int;
      final DateTime moment = DateTime(2026, 1, 4 + (at['weekday'] as int), minutes ~/ 60, minutes % 60);
      expect(hours.isOpenAt(moment), c['open']);
    });
  }
}
