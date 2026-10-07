import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/app/local_saathi_app.dart';
import 'package:localsaathi/core/widgets/provider_card.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/domain/models/enums.dart';
import 'package:localsaathi/features/provider_profile/report_listing_sheet.dart';

// Phase 002 flows the browser walkthrough did not exercise: Hindi locale,
// large-text scaling and the report sheet.
Future<AppDependencies> _pumpHome(WidgetTester tester, {String? language}) async {
  final InMemoryKeyValueStore store = InMemoryKeyValueStore();
  await store.setString(StorageKeys.onboardingCompleted, 'true');
  if (language != null) await store.setString(StorageKeys.languageCode, language);
  final AppDependencies dependencies = await AppDependencies.mock(
    keyValueStore: store,
    persist: false,
    now: DateTime(2026, 1, 5, 10),
  );
  await tester.pumpWidget(LocalSaathiApp(dependencies: dependencies));
  await tester.pumpAndSettle();
  return dependencies;
}

void main() {
  testWidgets('home renders in Hindi without exceptions', (WidgetTester tester) async {
    await _pumpHome(tester, language: 'hi');
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('home renders at 2x text scale on a 375px phone without exceptions', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHome(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report sheet submits through ReportRepository', (WidgetTester tester) async {
    final AppDependencies dependencies = await _pumpHome(tester);
    final BuildContext context = tester.element(find.byType(ProviderCard, skipOffstage: false).first);
    showReportListingSheet(context, providerId: 'provider-x', providerName: 'Test listing');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wrong phone number'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Report'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await dependencies.reports.hasReported('provider-x'), isTrue);
    expect((await dependencies.reports.myReports()).first.reason, ReportReason.wrongPhoneNumber);
  });

  // Plan rule: phone verification must never imply a professional check. Any
  // English copy that says "verified" must say what was verified.
  test('no user-facing copy claims an unqualified "verified"', () {
    // A single-quoted Dart literal on one line, allowing escaped quotes.
    final RegExp literal =
        RegExp(r"'((?:[^'\\\n]|\\.)*verified(?:[^'\\\n]|\\.)*)'", caseSensitive: false);
    final List<String> offenders = <String>[
      for (final File f in Directory('lib/core/l10n').listSync().whereType<File>())
        for (final RegExpMatch m in literal.allMatches(f.readAsStringSync()))
          if (!RegExp(r'phone|credential|not verified|are not verified', caseSensitive: false)
              .hasMatch(m.group(1)!))
            '${f.path}: ${m.group(1)}',
    ];
    expect(offenders, isEmpty);
  });
}
