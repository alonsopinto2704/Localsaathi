import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/core/theme/app_spacing.dart';
import 'package:localsaathi/core/widgets/reveal.dart';

void main() {
  testWidgets('Reveal waits out its stagger, then settles fully visible',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Reveal(index: 2, child: Text('card')),
      ),
    );
    double opacity() => tester.widget<Opacity>(find.byType(Opacity)).opacity;

    expect(opacity(), 0);
    await tester.pump(AppDurations.stagger * 2);
    expect(opacity(), 0, reason: 'still inside the stagger delay');
    await tester.pump(AppDurations.reveal ~/ 2);
    expect(opacity(), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('Reveal is skipped when the system asks for reduced motion',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Reveal(child: Text('card')),
        ),
      ),
    );
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('card'), findsOneWidget);
  });
}
