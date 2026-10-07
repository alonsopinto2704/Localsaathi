import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/app/local_saathi_app.dart';
import 'package:localsaathi/core/widgets/provider_card.dart';
import 'package:localsaathi/data/local/key_value_store.dart';

void main() {
  // The home screen once threw on its first build (a setState closure that
  // returned a Future), and no test exercised the widget tree to notice.
  testWidgets('a returning customer lands on a populated home screen',
      (WidgetTester tester) async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await store.setString(StorageKeys.onboardingCompleted, 'true');
    final AppDependencies dependencies = await AppDependencies.mock(
      keyValueStore: store,
      persist: false,
      now: DateTime(2026, 1, 5, 10),
    );

    await tester.pumpWidget(LocalSaathiApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CategoryTile), findsWidgets);
    expect(find.byType(ProviderCard, skipOffstage: false), findsWidgets);
  });
}
