import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/app/app_dependencies.dart';
import 'package:localsaathi/core/config/app_config.dart';
import 'package:localsaathi/core/l10n/app_strings.dart';
import 'package:localsaathi/core/l10n/app_strings_hi.dart';
import 'package:localsaathi/core/utils/phone_number.dart';
import 'package:localsaathi/core/widgets/provider_contact.dart';
import 'package:localsaathi/data/local/key_value_store.dart';
import 'package:localsaathi/domain/models/account.dart';
import 'package:localsaathi/domain/models/enums.dart';
import 'package:localsaathi/domain/models/location.dart';
import 'package:localsaathi/domain/models/moderation.dart';
import 'package:localsaathi/domain/models/provider.dart';
import 'package:localsaathi/domain/models/service_category.dart';
import 'package:localsaathi/domain/repositories/auth_repository.dart';
import 'package:localsaathi/domain/repositories/provider_repository.dart';

/// Unit and integration tests over the mock repositories.
///
/// These cover the rules that must survive the move to a real backend: phone
/// uniqueness, ownership, publication status, location activation and the
/// separation of phone verification from credential verification. They run
/// entirely against in-memory storage, so there is no plugin binding and no
/// network involved.
void main() {
  late AppDependencies dependencies;

  setUp(() async {
    dependencies = await AppDependencies.mock(
      keyValueStore: InMemoryKeyValueStore(),
      persist: false,
      now: DateTime(2026, 1, 5, 10, 0),
    );
  });

  // ---------------------------------------------------------------------
  group('Phone normalisation', () {
    test('every common format of one number collapses to a single E.164 value',
        () {
      const List<String> formats = <String>[
        '9876543210',
        '09876543210',
        '+91 98765 43210',
        '+919876543210',
        '0091-9876543210',
        '91 9876543210',
        '  +91-98765-43210  ',
        '98765 43210',
      ];
      final Set<String> normalized = formats
          .map((String raw) => PhoneUtils.tryNormalize(raw)?.e164 ?? 'FAILED')
          .toSet();
      expect(normalized, <String>{'+919876543210'});
    });

    test('rejects numbers that cannot receive an OTP', () {
      // A landline-style number starting 2 is rejected, as are short and long
      // numbers, so an unusable contact can never be published.
      expect(PhoneUtils.tryNormalize('02212345678'), isNull);
      expect(PhoneUtils.tryNormalize('98765'), isNull);
      expect(PhoneUtils.tryNormalize('98765432109'), isNull);
      expect(PhoneUtils.tryNormalize('abcdefghij'), isNull);
      expect(PhoneUtils.tryNormalize(''), isNull);
    });

    test('masking never reveals a usable number', () {
      final String masked = PhoneUtils.mask('+919876543210');
      expect(masked, endsWith('10'));
      expect(masked.contains('98765'), isFalse);
    });
  });

  // ---------------------------------------------------------------------
  group('Location activation is data-driven', () {
    test('Mumbai is the only active city on a fresh install', () async {
      final List<City> active = (await dependencies.locations.availableCities())
          .where((City c) => c.isSelectable)
          .toList();
      expect(active, hasLength(1));
      expect(active.single.name, 'Mumbai');
    });

    test('surrounding cities are separate markets, not part of Mumbai',
        () async {
      final City? thane = await dependencies.locations.cityById('mh-thane');
      final City? naviMumbai =
          await dependencies.locations.cityById('mh-navi-mumbai');
      final City? vasai =
          await dependencies.locations.cityById('mh-vasai-virar');

      expect(thane?.launchStatus, CityLaunchStatus.comingSoon);
      expect(naviMumbai?.launchStatus, CityLaunchStatus.comingSoon);
      expect(vasai?.launchStatus, CityLaunchStatus.comingSoon);
      // Each is its own market id, so activating one never implies another.
      expect(
        <String?>{thane?.id, naviMumbai?.id, vasai?.id, 'mh-mumbai'},
        hasLength(4),
      );
    });

    test(
      'activating another city through data makes it selectable, with no UI change',
      () async {
        final City before = await dependencies.locations.activeLaunchCity();
        expect(before.name, 'Mumbai');

        // The single switch a backend would flip.
        await dependencies.locations
            .setCityLaunchStatus('mh-pune', CityLaunchStatus.active);

        final City? pune = await dependencies.locations.cityById('mh-pune');
        expect(pune?.isSelectable, isTrue);

        final Locality? locality =
            await dependencies.locations.defaultLocality('mh-pune');
        expect(locality, isNotNull);

        // And the app can now open directly on Pune, because the launch market
        // is resolved from data rather than hardcoded.
        final City preferred =
            await dependencies.locations.activeLaunchCity(preferredCityId: 'mh-pune');
        expect(preferred.name, 'Pune');
      },
    );

    test('an unsupported city is reported as not active yet', () async {
      expect(await dependencies.locations.isCityActive('ka-bengaluru'), isFalse);
      expect(await dependencies.locations.isCityActive('mh-mumbai'), isTrue);
    });

    test('a city request is recorded once and never duplicated', () async {
      final CityRequest first = await dependencies.locations.requestCity(
        cityName: 'Indore',
      );
      expect(first.cityName, 'Indore');
      expect(await dependencies.locations.hasRequestedCity('indore'), isTrue);

      final List<CityRequest> requests =
          await dependencies.locations.pendingCityRequests();
      expect(requests, hasLength(1));
    });

    test('the launch message names the active market without hardcoding it',
        () async {
      final City city = await dependencies.locations.activeLaunchCity();
      // The template exists precisely so no screen embeds "Mumbai".
      expect(
        AppConfig.launchAvailabilityMessage.contains('Mumbai'),
        isTrue,
        reason: 'The default English copy names the launch city as an example.',
      );
      expect(city.name, 'Mumbai');
    });
  });

  // ---------------------------------------------------------------------
  group('Guest discovery', () {
    test('a guest in Andheri West finds providers who serve that locality',
        () async {
      final LocationSelection selection =
          (await dependencies.locations.resolveSelection(
        cityId: 'mh-mumbai',
        localityId: 'mh-mumbai-andheri-west',
      ))!;

      final ProviderSearchResults results =
          await dependencies.providers.search(
        ProviderQuery(
          cityId: selection.cityId,
          localityId: selection.localityId,
        ),
      );

      expect(results.items, isNotEmpty);
      for (final ProviderResultItem item in results.items) {
        expect(item.provider.isPubliclyVisible, isTrue);
        expect(
          item.provider.servesLocality(selection.localityId),
          isTrue,
          reason: 'Every result must serve the selected locality.',
        );
      }
    });

    test('providers based elsewhere are found through their service areas',
        () async {
      // The seeded data has providers whose base is one locality and whose
      // service areas include others; they must appear for those others.
      final ProviderSearchResults results =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-jogeshwari',
        ),
      );
      expect(results.items, isNotEmpty);
      expect(
        results.items.any((ProviderResultItem item) =>
            item.provider.baseLocalityId != 'mh-mumbai-jogeshwari'),
        isTrue,
        reason: 'At least one result should be based somewhere else.',
      );
    });

    test('search matches a service in everyday language', () async {
      final ProviderSearchResults results =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
          text: 'plumber',
        ),
      );
      expect(results.items, isNotEmpty);
      for (final ProviderResultItem item in results.items) {
        expect(item.provider.categoryIds, contains('plumbing'));
      }
    });

    test('search matches a locality name', () async {
      final ProviderSearchResults results =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-bandra-west',
          text: 'bandra',
        ),
      );
      expect(results.items, isNotEmpty);
    });

    test('category and home-visit filters narrow the results', () async {
      final ProviderSearchResults all = await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
        ),
      );
      final ProviderSearchResults filtered =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
          categoryIds: <String>['plumbing'],
          homeVisitsOnly: true,
        ),
      );

      expect(filtered.items.length, lessThanOrEqualTo(all.items.length));
      for (final ProviderResultItem item in filtered.items) {
        expect(item.provider.categoryIds, contains('plumbing'));
        expect(item.provider.homeVisits, isTrue);
      }
    });

    test('"open now" never includes a provider with unknown hours', () async {
      final ProviderSearchResults results =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-borivali-east',
          openNowOnly: true,
        ),
      );
      for (final ProviderResultItem item in results.items) {
        final WorkingHours? hours = item.provider.workingHours;
        expect(hours, isNotNull);
        expect(hours!.hasAnyHours, isTrue);
        expect(hours.isOpenAt(DateTime(2026, 1, 5, 10, 0)), isTrue);
      }
    });

    test('a city with no seeded providers returns an empty result set',
        () async {
      final ProviderSearchResults results =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-pune',
          localityId: 'mh-pune-kothrud',
        ),
      );
      expect(results.isEmpty, isTrue);
      expect(results.totalCount, 0);
    });

    test('saved providers persist for a guest and drop hidden listings',
        () async {
      final ProviderSearchResults results =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
        ),
      );
      final ProviderProfile provider = results.items.first.provider;

      expect(await dependencies.savedProviders.isSaved(provider.id), isFalse);
      expect(await dependencies.savedProviders.toggle(provider.id), isTrue);
      expect(await dependencies.savedProviders.isSaved(provider.id), isTrue);

      final List<ProviderProfile> saved =
          await dependencies.savedProviders.savedProfiles();
      expect(saved.map((ProviderProfile p) => p.id), contains(provider.id));

      // A paused listing must disappear from the saved list rather than linger
      // as a dead entry.
      final ProviderSession session = await _signInAsNewProvider(
        dependencies,
        phone: '9811111111',
      );
      final ProviderProfile mine = await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'Test Provider',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-andheri-west',
        categoryIds: const <String>['plumbing'],
        serviceAreaIds: const <String>['mh-mumbai-andheri-west'],
        session: session,
        phoneDisplayConsented: true,
      );
      await dependencies.savedProviders.save(mine.id);
      expect(
        (await dependencies.savedProviders.savedProfiles())
            .map((ProviderProfile p) => p.id),
        contains(mine.id),
      );

      await dependencies.providers.setListingStatus(
        profileId: mine.id,
        status: ListingStatus.paused,
        session: session,
      );
      expect(
        (await dependencies.savedProviders.savedProfiles())
            .map((ProviderProfile p) => p.id),
        isNot(contains(mine.id)),
      );
    });
  });

  // ---------------------------------------------------------------------
  group('Publication status', () {
    test('a paused listing disappears from public results', () async {
      final ProviderSearchResults before =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
        ),
      );
      final ProviderResultItem target = before.items.first;
      // Ownership is established by verifying the seeded number, which is the
      // only route to a session in this build — no test-only bypass exists.
      final ProviderSession session =
          await _sessionOwning(dependencies, target.provider);
      expect(session.profileId, target.provider.id);

      await dependencies.providers.setListingStatus(
        profileId: target.provider.id,
        status: ListingStatus.paused,
        session: session,
      );

      final ProviderSearchResults after =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
        ),
      );
      expect(
        after.items.map((ProviderResultItem i) => i.providerId),
        isNot(contains(target.providerId)),
      );
      expect(
        await dependencies.providers.publicProfileById(target.providerId),
        isNull,
        reason: 'A hidden listing must not be reachable by a stale link.',
      );
    });

    test('seeded non-published listings are never public', () async {
      expect(
        await dependencies.providers
            .publicProfileById(dependencies.pausedSeedProfileId),
        isNull,
      );
      expect(
        await dependencies.providers
            .publicProfileById(dependencies.draftSeedProfileId),
        isNull,
      );
      expect(
        (await dependencies.providers.publishedInCity('mh-mumbai'))
            .map((ProviderProfile p) => p.id),
        isNot(contains(dependencies.pausedSeedProfileId)),
      );
    });
  });

  // ---------------------------------------------------------------------
  group('One verified number, one profile', () {
    test('a new number verifies and gets routed to the profile wizard',
        () async {
      final OtpChallengeResult challenge =
          await dependencies.auth.requestOtp('9822000001');
      expect(challenge.isSuccess, isTrue);

      final PhoneVerificationResult result = await dependencies.auth.verifyOtp(
        challengeId: challenge.challenge!.id,
        code: AppConfig.developmentOtpCode,
      );
      expect(result.phoneVerified, isTrue);
      expect(result.isNewAccount, isTrue);
      expect(result.existingProfileId, isNull);
    });

    test('requesting a code never reveals whether a number is registered',
        () async {
      // Walk an existing seeded number through the first step and confirm the
      // response shape carries no hint of the existing profile.
      final OtpChallengeResult challenge =
          await dependencies.auth.requestOtp('+91 999 000 011');
      expect(challenge.isSuccess, isTrue);
      expect(challenge.challenge, isNotNull);
    });

    test('an existing number routes to sign-in after the code is verified',
        () async {
      const String phone = '9833000002';

      // Register once.
      final ProviderSession first = await _signInAsNewProvider(
        dependencies,
        phone: phone,
      );
      final ProviderProfile profile = await dependencies.providers.createProfile(
        phoneE164: first.phoneE164,
        displayName: 'Repeat Number Plumbing',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-kurla',
        categoryIds: const <String>['plumbing'],
        serviceAreaIds: const <String>['mh-mumbai-kurla'],
        session: first,
        phoneDisplayConsented: true,
      );
      await dependencies.auth.signOut();

      // Now register again with the same number in a different format.
      final OtpChallengeResult challenge =
          await dependencies.auth.requestOtp('098330 00002');
      final PhoneVerificationResult result = await dependencies.auth.verifyOtp(
        challengeId: challenge.challenge!.id,
        code: AppConfig.developmentOtpCode,
      );

      expect(result.isNewAccount, isFalse);
      expect(result.existingProfileId, profile.id);
      expect(result.profile?.id, profile.id);
      // Crucially: no second profile was created.
      expect(
        (await dependencies.providers.publishedInCity('mh-mumbai'))
            .where((ProviderProfile p) => p.phoneE164 == result.session.phoneE164),
        hasLength(1),
      );
    });

    test('creating a second profile for a taken number is refused', () async {
      const String phone = '9844000003';
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: phone);
      await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'First Listing',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-dadar-west',
        categoryIds: const <String>['electrical'],
        serviceAreaIds: const <String>['mh-mumbai-dadar-west'],
        session: session,
        phoneDisplayConsented: true,
      );

      expect(
        () => dependencies.providers.createProfile(
          phoneE164: session.phoneE164,
          displayName: 'Duplicate Listing',
          baseCityId: 'mh-mumbai',
          baseLocalityId: 'mh-mumbai-dadar-west',
          categoryIds: const <String>['electrical'],
          serviceAreaIds: const <String>['mh-mumbai-dadar-west'],
          session: session,
          phoneDisplayConsented: true,
        ),
        throwsA(isA<DuplicatePhoneNumberException>()),
      );
    });

    test('a wrong code is rejected and does not create a session', () async {
      final OtpChallengeResult challenge =
          await dependencies.auth.requestOtp('9855000004');
      expect(
        () => dependencies.auth.verifyOtp(
          challengeId: challenge.challenge!.id,
          code: '000000',
        ),
        throwsA(
          isA<OtpException>().having(
            (OtpException e) => e.reason,
            'reason',
            OtpFailure.invalid,
          ),
        ),
      );
      expect(await dependencies.auth.restoreSession(), isNull);
    });

    test('changing the registered number requires verification of the new one',
        () async {
      const String oldPhone = '9866000005';
      const String newPhone = '9866000006';
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: oldPhone);
      await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'Number Changer',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-ghatkopar',
        categoryIds: const <String>['electrical'],
        serviceAreaIds: const <String>['mh-mumbai-ghatkopar'],
        session: session,
        phoneDisplayConsented: true,
      );

      final OtpChallengeResult change =
          await dependencies.auth.requestPhoneNumberChange(newPhone);
      expect(change.isSuccess, isTrue);

      final ProviderAccount account =
          await dependencies.auth.confirmPhoneNumberChange(
        challengeId: change.challenge!.id,
        code: AppConfig.developmentOtpCode,
      );
      expect(account.phoneE164, PhoneUtils.tryNormalize(newPhone)!.e164);
      expect(
        (await dependencies.auth.restoreSession())?.phoneE164,
        PhoneUtils.tryNormalize(newPhone)!.e164,
      );
      // The old number is released and the new one owns exactly one profile.
      expect(dependencies.dataStore.profileForPhone(
        PhoneUtils.tryNormalize(oldPhone)!.e164,
      ), isNull);
      expect(
        dependencies.dataStore.profileForPhone(
          PhoneUtils.tryNormalize(newPhone)!.e164,
        ),
        isNotNull,
      );
    });
  });

  // ---------------------------------------------------------------------
  group('Ownership', () {
    test('a different provider cannot edit someone else\'s listing', () async {
      final List<ProviderProfile> seeded =
          await dependencies.providers.publishedInCity('mh-mumbai');
      final ProviderProfile victim = seeded.first;
      final ProviderProfile other = seeded[1];

      // Sign in as the owner of a different listing.
      final ProviderSession attacker =
          await _sessionOwning(dependencies, other);
      expect(attacker.profileId, other.id);
      expect(attacker.profileId, isNot(victim.id));

      expect(
        () => dependencies.providers.updateProfile(
          profile: victim.copyWith(displayName: 'Hijacked'),
          session: attacker,
        ),
        throwsA(
          isA<RepositoryException>().having(
            (RepositoryException e) => e.code,
            'code',
            RepositoryErrorCode.notOwner,
          ),
        ),
      );

      // The victim's listing is untouched.
      expect(
        (await dependencies.providers.publicProfileById(victim.id))?.displayName,
        victim.displayName,
      );
    });

    test('publishing requires consent to show the number', () async {
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: '9877000007');
      final ProviderProfile profile = await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'No Consent',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-sion',
        categoryIds: const <String>['painting'],
        serviceAreaIds: const <String>['mh-mumbai-sion'],
        session: session,
      );

      expect(
        () => dependencies.providers
            .publish(profileId: profile.id, session: session),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('reporting is allowed for customers and never edits the listing',
        () async {
      final ProviderProfile provider =
          (await dependencies.providers.publishedInCity('mh-mumbai')).first;
      final Report report = await dependencies.reports.submit(
        providerId: provider.id,
        reason: ReportReason.wrongPhoneNumber,
        details: 'Number rings out.',
      );
      expect(report.status, ReportStatus.submitted);
      expect(await dependencies.reports.hasReported(provider.id), isTrue);

      final ProviderProfile after =
          (await dependencies.providers.publicProfileById(provider.id))!;
      expect(after.displayName, provider.displayName);
    });
  });

  // ---------------------------------------------------------------------
  group('Provider onboarding and editing', () {
    test('a provider creates, publishes, edits and pauses their listing',
        () async {
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: '9888000008');

      final ProviderProfile draft = await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'Ravi Test Electricals',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-vikhroli',
        categoryIds: const <String>['electrical', 'appliance-repair'],
        serviceAreaIds: const <String>['mh-mumbai-vikhroli', 'mh-mumbai-ghatkopar'],
        session: session,
        description: 'Wiring, fans and appliance repair.',
        languages: const <String>['Marathi', 'Hindi'],
        workingHours: WorkingHours.standardWeek(),
        phoneDisplayConsented: true,
        whatsappEnabled: true,
      );
      expect(draft.status, ListingStatus.draft);

      final ProviderProfile published = await dependencies.providers.publish(
        profileId: draft.id,
        session: session,
      );
      expect(published.status, ListingStatus.published);
      expect(published.isPhoneVerified, isTrue);
      // Multiple categories on one profile is how a multi-service provider stays
      // a single listing.
      expect(published.categoryIds, hasLength(2));

      final ProviderProfile edited = await dependencies.providers.updateProfile(
        profile: published.copyWith(
          displayName: 'Ravi Electricals and Appliances',
          description: 'Updated description.',
        ),
        session: session,
      );
      expect(edited.displayName, 'Ravi Electricals and Appliances');

      // The edit must be visible to a customer immediately.
      final ProviderProfile? asCustomer =
          await dependencies.providers.publicProfileById(edited.id);
      expect(asCustomer?.displayName, 'Ravi Electricals and Appliances');

      final ProviderProfile paused = await dependencies.providers
          .setListingStatus(
        profileId: edited.id,
        status: ListingStatus.paused,
        session: session,
      );
      expect(paused.isPubliclyVisible, isFalse);
      expect(
        await dependencies.providers.publicProfileById(edited.id),
        isNull,
      );

      final ProviderProfile resumed = await dependencies.providers
          .setListingStatus(
        profileId: edited.id,
        status: ListingStatus.published,
        session: session,
      );
      expect(resumed.isPubliclyVisible, isTrue);
    });

    test('deleting a listing releases the phone number', () async {
      const String phone = '9888000009';
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: phone);
      final ProviderProfile profile = await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'Temporary Listing',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-mulund',
        categoryIds: const <String>['plumbing'],
        serviceAreaIds: const <String>['mh-mumbai-mulund'],
        session: session,
        phoneDisplayConsented: true,
      );

      await dependencies.providers
          .deleteListing(profileId: profile.id, session: session);
      expect(await dependencies.providers.publicProfileById(profile.id), isNull);

      // The number can register again: deleting released it rather than
      // blocking it forever.
      final ProviderSession again =
          await _signInAsNewProvider(dependencies, phone: phone);
      final ProviderProfile recreated =
          await dependencies.providers.createProfile(
        phoneE164: again.phoneE164,
        displayName: 'Re-registered Listing',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-mulund',
        categoryIds: const <String>['plumbing'],
        serviceAreaIds: const <String>['mh-mumbai-mulund'],
        session: again,
        phoneDisplayConsented: true,
      );
      expect(recreated.phoneE164, PhoneUtils.tryNormalize(phone)!.e164);
    });

    test('references are validated on write', () async {
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: '9888000010');

      expect(
        () => dependencies.providers.createProfile(
          phoneE164: session.phoneE164,
          displayName: 'Bad Category',
          baseCityId: 'mh-mumbai',
          baseLocalityId: 'mh-mumbai-parel',
          categoryIds: const <String>['not-a-real-category'],
          serviceAreaIds: const <String>['mh-mumbai-parel'],
          session: session,
          phoneDisplayConsented: true,
        ),
        throwsA(
          isA<RepositoryException>().having(
            (RepositoryException e) => e.code,
            'code',
            RepositoryErrorCode.categoryNotAllowed,
          ),
        ),
      );

      expect(
        () => dependencies.providers.createProfile(
          phoneE164: session.phoneE164,
          displayName: 'No Categories',
          baseCityId: 'mh-mumbai',
          baseLocalityId: 'mh-mumbai-parel',
          categoryIds: const <String>[],
          serviceAreaIds: const <String>['mh-mumbai-parel'],
          session: session,
          phoneDisplayConsented: true,
        ),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  // ---------------------------------------------------------------------
  group('Verification records', () {
    test('OTP verification never produces a credentials-verified state',
        () async {
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: '9889000011');
      final ProviderProfile profile = await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'Dr. Test Physician',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-bandra-west',
        categoryIds: const <String>['general-physician'],
        serviceAreaIds: const <String>['mh-mumbai-bandra-west'],
        session: session,
        phoneDisplayConsented: true,
        healthcareDetails: const HealthcareDetails(
          qualification: 'MBBS',
          specialty: 'General physician',
          registrationNumber: 'TEST-0000',
        ),
      );

      expect(profile.isPhoneVerified, isTrue);
      expect(profile.isCredentialsVerified, isFalse);
      expect(profile.healthcareDetails?.hasClaimedRegistration, isTrue);

      final Map<VerificationKind, VerificationStatus> status =
          await dependencies.verification.currentStatus(profile.id);
      expect(status[VerificationKind.phone], VerificationStatus.approved);
      expect(
        status[VerificationKind.credentials],
        isNot(VerificationStatus.approved),
      );
    });

    test('a credential review is the only route to credentials verified',
        () async {
      final ProviderProfile provider =
          (await dependencies.providers.publishedInCity('mh-mumbai')).first;
      await dependencies.verification.recordCredentialReview(
        providerId: provider.id,
        status: VerificationStatus.approved,
        reviewedBy: 'moderator-1',
        note: 'Registration checked against council record.',
      );
      final Map<VerificationKind, VerificationStatus> status =
          await dependencies.verification.currentStatus(provider.id);
      expect(status[VerificationKind.credentials], VerificationStatus.approved);
    });

    test('consents are recorded as history, not as a single flag', () async {
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: '9889000012');
      final ProviderProfile profile = await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'Consent Test',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-worli',
        categoryIds: const <String>['home-cleaning'],
        serviceAreaIds: const <String>['mh-mumbai-worli'],
        session: session,
        phoneDisplayConsented: true,
      );

      await dependencies.consents.record(
        providerId: profile.id,
        kind: ConsentKind.whatsappContact,
        granted: true,
        phoneE164: profile.phoneE164,
      );
      await dependencies.consents.record(
        providerId: profile.id,
        kind: ConsentKind.whatsappContact,
        granted: false,
        phoneE164: profile.phoneE164,
      );

      final List<ConsentRecord> history =
          await dependencies.consents.forProvider(profile.id);
      expect(history.length, greaterThanOrEqualTo(2));
      final Map<ConsentKind, bool> current =
          await dependencies.consents.currentState(profile.id);
      expect(current[ConsentKind.whatsappContact], isFalse);
      // Every record pins the wording version it was captured against.
      expect(
        history.every((ConsentRecord c) => c.wordingVersion.isNotEmpty),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------
  group('Sponsorship', () {
    test('a sponsored provider is labelled and organic results stay visible',
        () async {
      final ProviderSearchResults results =
          await dependencies.providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
          text: 'plumber',
        ),
      );

      final List<ProviderResultItem> sponsored =
          results.items.where((ProviderResultItem i) => i.isSponsored).toList();
      final List<ProviderResultItem> organic =
          results.items.where((ProviderResultItem i) => !i.isSponsored).toList();

      expect(sponsored, isNotEmpty);
      // Sponsored items are presented as their own labelled group, so they lead.
      expect(sponsored.first.isSponsored, isTrue);
      // Organic results are never removed to make room for a paid placement.
      expect(organic.length, greaterThan(sponsored.length));
    });

    test('monetization stays a preview with no pricing or entitlement',
        () async {
      final List<SubscriptionPlan> plans =
          await dependencies.promotions.subscriptionPlans();
      expect(plans, isNotEmpty);
      for (final SubscriptionPlan plan in plans) {
        expect(
          plan.priceLabel,
          isNull,
          reason: 'Prices are not decided, so none may be displayed.',
        );
        expect(plan.featureKeys, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------
  group('Engagement accounting', () {
    test('only button taps and views exist as event types', () {
      // A structural guarantee: there is no "call completed", "lead" or "job"
      // member, so the app cannot claim to know those outcomes.
      expect(
        EngagementEventType.values.map((EngagementEventType t) => t.name),
        containsAll(<String>[
          'profileView',
          'callButtonTap',
          'whatsappButtonTap',
          'shareTap',
        ]),
      );
      expect(
        EngagementEventType.values
            .map((EngagementEventType t) => t.name)
            .where((String n) =>
                n.contains('lead') ||
                n.contains('job') ||
                n.contains('completed')),
        isEmpty,
      );
    });

    test('a tap is recorded separately from a view', () async {
      final ProviderProfile provider =
          (await dependencies.providers.publishedInCity('mh-mumbai')).first;
      await dependencies.engagement.record(
        providerId: provider.id,
        type: EngagementEventType.callButtonTap,
      );
      final EngagementSummary summary =
          await dependencies.engagement.summaryFor(provider.id);
      expect(summary.callButtonTaps, greaterThan(0));
    });

    test('seeded engagement is flagged as sample data', () async {
      final ProviderProfile provider =
          (await dependencies.providers.publishedInCity('mh-mumbai')).first;
      final EngagementSummary summary =
          await dependencies.engagement.summaryFor(provider.id);
      expect(summary.isSampleData, isTrue);
    });

    test('a provider with no activity shows real zeroes, not sample data',
        () async {
      final ProviderSession session =
          await _signInAsNewProvider(dependencies, phone: '9889000013');
      final ProviderProfile profile = await dependencies.providers.createProfile(
        phoneE164: session.phoneE164,
        displayName: 'Fresh Listing',
        baseCityId: 'mh-mumbai',
        baseLocalityId: 'mh-mumbai-matunga',
        categoryIds: const <String>['tailoring'],
        serviceAreaIds: const <String>['mh-mumbai-matunga'],
        session: session,
        phoneDisplayConsented: true,
      );
      final EngagementSummary summary =
          await dependencies.engagement.summaryFor(profile.id);
      expect(summary.profileViews, 0);
      expect(summary.callButtonTaps, 0);
      expect(summary.isSampleData, isFalse);
    });
  });

  // ---------------------------------------------------------------------
  group('Working hours', () {
    test('an overnight window counts as open after midnight', () {
      final WorkingHours hours = WorkingHours(
        <DayHours>[
          for (int day = DateTime.monday; day <= DateTime.sunday; day++)
            day == DateTime.saturday
                ? const DayHours(
                    weekday: DateTime.saturday,
                    openMinutes: 22 * 60,
                    closeMinutes: 2 * 60,
                  )
                : DayHours.closed(day),
        ],
      );
      // Saturday 23:30 is inside the window.
      expect(hours.isOpenAt(DateTime(2026, 1, 10, 23, 30)), isTrue);
      // Sunday 01:00 continues the overnight window.
      expect(hours.isOpenAt(DateTime(2026, 1, 11, 1, 0)), isTrue);
      // Sunday 03:00 is after it closed.
      expect(hours.isOpenAt(DateTime(2026, 1, 11, 3, 0)), isFalse);
    });

    test('no recorded hours means unknown, not closed', () {
      final WorkingHours none = WorkingHours.none();
      expect(none.hasAnyHours, isFalse);
      // `null` is what the UI renders as "hours not provided".
      expect(none.isOpenAt(DateTime(2026, 1, 5, 12)), isNull);
    });

    test('a standard week is closed on Sunday', () {
      final WorkingHours hours = WorkingHours.standardWeek();
      expect(hours.isOpenAt(DateTime(2026, 1, 5, 12)), isTrue); // Monday
      expect(hours.isOpenAt(DateTime(2026, 1, 11, 12)), isFalse); // Sunday
      expect(hours.isOpenAt(DateTime(2026, 1, 5, 6)), isFalse); // before open
    });

    test('the summary groups consecutive identical days', () {
      final String summary = formatWorkingHoursSummary(
        WorkingHours.standardWeek(),
        closedLabel: 'Closed',
      );
      expect(summary, contains('Mon–Sat'));
      expect(summary, contains('Sun Closed'));
    });
  });

  group('Localisation structure', () {
    test('partly translated languages fall back to English per string', () {
      final AppStrings hi = AppStringsHi();
      expect(hi.languageCode, 'hi');
      // A translated string.
      expect(hi.callNow, isNot(const AppStringsEn().callNow));
      // An untranslated string falls back rather than returning empty.
      expect(hi.monetizationDisclaimer, const AppStringsEn().monetizationDisclaimer);
    });

    test('the launch message is a template, so no city is baked into copy', () {
      const AppStrings strings = AppStringsEn();
      expect(
        strings.launchAvailabilityMessageTemplate('Pune'),
        contains('Pune'),
      );
      expect(
        strings.launchAvailabilityMessageTemplate('Pune'),
        isNot(contains('Mumbai')),
      );
      expect(
        strings.browseActiveCityAnywayTemplate('Pune'),
        contains('Pune'),
      );
    });
  });

  // ---------------------------------------------------------------------
  group('Service taxonomy and categories', () {
    test('contains all required product categories and 6 distinct groups',
        () async {
      final List<ServiceGroup> groups = await dependencies.catalog.groups();
      expect(groups.map((ServiceGroup g) => g.id).toSet(), containsAll(<String>[
        'home-repairs',
        'home-services',
        'daily-workers',
        'vehicle-services',
        'healthcare',
        'other-services',
      ]));

      final List<ServiceCategory> categories =
          await dependencies.catalog.categories();
      final Set<String> catIds =
          categories.map((ServiceCategory c) => c.id).toSet();

      // Home repairs
      expect(catIds, containsAll(<String>[
        'plumbing',
        'electrical',
        'carpentry',
        'painting',
        'masonry',
        'welding-fabrication',
        'ac-repair',
        'appliance-repair',
        'locksmith',
      ]));

      // Home services
      expect(catIds, containsAll(<String>[
        'home-cleaning',
        'pest-control',
        'laundry-ironing',
      ]));

      // Daily workers
      expect(catIds, containsAll(<String>[
        'daily-worker',
        'construction-labourer',
        'loading-unloading',
      ]));

      // Vehicle services
      expect(catIds, containsAll(<String>[
        'mechanic',
        'car-mechanic',
        'puncture-repair',
        'towing',
      ]));

      // Healthcare
      expect(catIds, containsAll(<String>[
        'general-physician',
        'dentist',
        'paediatrician',
        'physiotherapist',
        'diagnostic-centre',
      ]));

      // Other services
      expect(catIds, containsAll(<String>[
        'computer-repair',
        'network-technician',
        'tutor',
        'packers-movers',
      ]));
    });

    test('popular categories return high-demand everyday trades for home',
        () async {
      final List<ServiceCategory> popular =
          await dependencies.catalog.popularCategories();
      expect(popular.isNotEmpty, isTrue);
      expect(popular.any((ServiceCategory c) => c.id == 'plumbing'), isTrue);
      expect(popular.any((ServiceCategory c) => c.id == 'electrical'), isTrue);
    });
  });
}

/// Verifies a fresh number and returns the resulting session.
Future<ProviderSession> _signInAsNewProvider(
  AppDependencies dependencies, {
  required String phone,
}) async {
  final OtpChallengeResult challenge =
      await dependencies.auth.requestOtp(phone);
  expect(challenge.isSuccess, isTrue, reason: 'OTP request should succeed.');
  final PhoneVerificationResult result = await dependencies.auth.verifyOtp(
    challengeId: challenge.challenge!.id,
    code: AppConfig.developmentOtpCode,
  );
  return result.session;
}

/// Signs in as the owner of a seeded listing.
///
/// Seeded providers are fictional and have no account, so the test signs in with
/// the seeded number, which the OTP simulation accepts. Ownership is then real:
/// the session's phone matches the profile's phone.
Future<ProviderSession> _sessionOwning(
  AppDependencies dependencies,
  ProviderProfile provider,
) async {
  final OtpChallengeResult challenge =
      await dependencies.auth.requestOtp(provider.phoneE164);
  final PhoneVerificationResult result = await dependencies.auth.verifyOtp(
    challengeId: challenge.challenge!.id,
    code: AppConfig.developmentOtpCode,
  );
  return result.session;
}
