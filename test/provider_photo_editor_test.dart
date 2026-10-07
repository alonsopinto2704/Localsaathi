import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/core/config/app_config.dart';
import 'package:localsaathi/core/l10n/app_localizations.dart';
import 'package:localsaathi/core/theme/app_theme.dart';
import 'package:localsaathi/core/widgets/provider_photos.dart';
import 'package:localsaathi/domain/models/provider.dart';

// A real 2x2 PNG, so Image.memory decodes rather than falling back.
const String _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGPkL8tjYGBgYgADAAsvAPeNyG/dAAAAAElFTkSuQmCC';

ProviderPhoto _photo(int i) =>
    ProviderPhoto(id: 'p$i', caption: '', imageBase64: _png);

Future<List<ProviderPhoto>> _pumpEditor(
  WidgetTester tester,
  List<ProviderPhoto> initial,
) async {
  List<ProviderPhoto> photos = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) =>
              ProviderPhotoEditor(
            photos: photos,
            onChanged: (List<ProviderPhoto> next) =>
                setState(() => photos = next),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return photos;
}

void main() {
  testWidgets('photos can be removed and the add tile offers more',
      (WidgetTester tester) async {
    await _pumpEditor(tester, <ProviderPhoto>[_photo(1), _photo(2)]);

    expect(find.byType(ProviderPhotoTile), findsNWidgets(2));
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.byType(ProviderPhotoTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at the free-listing limit the add tile disappears',
      (WidgetTester tester) async {
    await _pumpEditor(tester, <ProviderPhoto>[
      for (int i = 0; i < AppConfig.freePhotoLimit; i++) _photo(i),
    ]);

    expect(
      find.byType(ProviderPhotoTile),
      findsNWidgets(AppConfig.freePhotoLimit),
    );
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    expect(find.textContaining('up to 5 photos'), findsOneWidget);
  });
}
