import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/core/config/app_config.dart';
import 'package:localsaathi/core/l10n/app_localizations.dart';
import 'package:localsaathi/core/theme/app_theme.dart';
import 'package:localsaathi/domain/models/enums.dart';
import 'package:localsaathi/domain/models/provider.dart';
import 'package:localsaathi/features/legal/legal_documents.dart';
import 'package:localsaathi/features/legal/legal_screen.dart';

ProviderProfile _profile({GeoPoint? pin}) => ProviderProfile(
      id: 'p1',
      phoneE164: '+919820012345',
      displayName: 'Om Sai Electricals',
      baseCityId: 'mh-mumbai',
      baseLocalityId: 'mh-mumbai-andheri-west',
      status: ListingStatus.published,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      mapLocation: pin,
    );

void main() {
  group('Map location', () {
    test('survives the profile JSON round trip', () {
      const GeoPoint pin = GeoPoint(19.1364, 72.8296);
      final ProviderProfile back =
          ProviderProfile.fromJson(_profile(pin: pin).toJson());
      expect(back.mapLocation, pin);
    });

    test('is absent by default and stays absent', () {
      final ProviderProfile back = ProviderProfile.fromJson(_profile().toJson());
      expect(back.mapLocation, isNull);
      expect(_profile().toJson().containsKey('mapLocation'), isFalse);
    });

    test('turning the map off deletes the coordinates', () {
      final ProviderProfile on = _profile(pin: const GeoPoint(19, 72.8));
      expect(on.copyWith(displayName: 'x').mapLocation, isNotNull);
      expect(on.copyWith(clearMapLocation: true).mapLocation, isNull);
    });

    test('malformed or out-of-range points are dropped, not pinned', () {
      expect(GeoPoint.fromJson(<String, dynamic>{'lat': 91, 'lng': 72}), isNull);
      expect(GeoPoint.fromJson(<String, dynamic>{'lat': 19, 'lng': 181}), isNull);
      expect(GeoPoint.fromJson(<String, dynamic>{'lat': '19'}), isNull);
      expect(GeoPoint.fromJson(null), isNull);
    });
  });

  group('Legal pages', () {
    for (final LegalDoc doc in LegalDoc.values) {
      testWidgets('${doc.name} renders with the draft notice and contact',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            home: LegalScreen(doc: doc),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(legalDocument(doc).title), findsWidgets);
        if (!AppConfig.legalTextReviewed) {
          expect(
            find.textContaining('Draft pending legal review'),
            findsOneWidget,
          );
        }
      });
    }

    test('the Grievance Officer is published where the Rules require it', () {
      for (final LegalDoc doc in <LegalDoc>[
        LegalDoc.privacy,
        LegalDoc.terms,
        LegalDoc.grievance,
      ]) {
        final String text = legalDocument(doc)
            .sections
            .expand((LegalSection s) => s.paragraphs)
            .join('\n');
        expect(text, contains(AppConfig.grievanceOfficerEmail), reason: doc.name);
        expect(text, contains('24 hours'), reason: doc.name);
        expect(text, contains('15 days'), reason: doc.name);
      }
    });
  });
}
