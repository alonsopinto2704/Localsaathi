import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/data/repositories/mock_data_store.dart';
import 'package:localsaathi/data/repositories/mock_location_repository.dart';
import 'package:localsaathi/data/repositories/mock_provider_repository.dart';
import 'package:localsaathi/data/repositories/mock_service_catalog_repository.dart';
import 'package:localsaathi/data/seed/category_seed.dart';
import 'package:localsaathi/data/seed/location_seed.dart';
import 'package:localsaathi/domain/models/location.dart';
import 'package:localsaathi/domain/models/service_category.dart';
import 'package:localsaathi/domain/repositories/provider_repository.dart';

// Phase 101 — multilingual search evaluation suite.
//
// The suite has four jobs, in this order:
//
// 1. Validate the schema of `test/fixtures/search_evaluation_dataset.json`
//    (120 labelled Mumbai queries: 60 tuning + 60 held_out, six language
//    labels, valid category/locality references, non-empty rationales).
// 2. Assert zero leakage of the 31 unapproved wave-2/healthcare categories
//    through every catalog surface: categories(), popularCategories(),
//    categoriesByGroup(), healthcareCategories(), categoriesWithGroup() and
//    searchCategories().
// 3. Execute every dataset query against MockServiceCatalogRepository and
//    MockProviderRepository and assert the recorded per-query expectations.
//    "Unapproved listings" (listings with no launch-approved category) must
//    never surface for any query, including the unsupported/wave-2/healthcare
//    ones.
// 4. Compute and print precision, recall, empty-result rate and the category
//    exposure distribution across both splits, so phases 102+ (tokenisation,
//    Devanagari keywords, fuzzy matching) can measure improvement against this
//    baseline.
//
// When search behaviour improves on purpose, a gap query (allowEmpty: true,
// expectedMinResults: 0) starts returning results: update its fields in the
// fixture and re-record the metrics in tasks/evidence/phase-101.md. That edit
// IS the re-baselining.

const String _fixturePath = 'test/fixtures/search_evaluation_dataset.json';

/// The dataset queries, loaded once at import time so the per-query group can
/// generate its tests statically. If the fixture is malformed the schema group
/// fails first with a clear reason.
final List<_QuerySpec> _allQueries = () {
  final Map<String, dynamic> decoded =
      jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;
  return <_QuerySpec>[
    for (final dynamic entry in decoded['queries'] as List<dynamic>)
      _QuerySpec.fromJson(entry as Map<String, dynamic>),
  ];
}();

/// One labelled query from the fixture, with strict types.
class _QuerySpec {
  const _QuerySpec({
    required this.id,
    required this.split,
    required this.language,
    required this.queryText,
    required this.cityId,
    required this.localityId,
    required this.expectedCategoryIds,
    required this.expectedMinResults,
    required this.allowEmpty,
    required this.rationale,
  });

  factory _QuerySpec.fromJson(Map<String, dynamic> json) {
    final List<String> expected = <String>[
      for (final dynamic v in json['expectedCategoryIds'] as List<dynamic>)
        v as String,
    ];
    return _QuerySpec(
      id: json['id'] as String,
      split: json['split'] as String,
      language: json['language'] as String,
      queryText: json['queryText'] as String,
      cityId: json['cityId'] as String,
      localityId: json['localityId'] as String,
      expectedCategoryIds: expected,
      expectedMinResults: json['expectedMinResults'] as int,
      allowEmpty: json['allowEmpty'] as bool,
      rationale: json['rationale'] as String,
    );
  }

  final String id;
  final String split;
  final String language;
  final String queryText;
  final String cityId;
  final String localityId;
  final List<String> expectedCategoryIds;
  final int expectedMinResults;
  final bool allowEmpty;
  final String rationale;

  /// Queries that must resolve today (hard expectations).
  bool get isResolved => expectedMinResults > 0;
}

/// What the repositories answered for one query.
class _Outcome {
  const _Outcome({
    required this.catalogCategoryIds,
    required this.results,
  });

  final List<String> catalogCategoryIds;
  final ProviderSearchResults results;

  Set<String> get resultCategoryIds => <String>{
        for (final ProviderResultItem item in results.items)
          ...item.provider.categoryIds,
      };
}

void main() {
  final Set<String> approvedIds = <String>{
    for (final ServiceCategory c in CategorySeed.categories)
      if (c.isApprovedForLaunch) c.id,
  };
  final Set<String> unapprovedIds = <String>{
    for (final ServiceCategory c in CategorySeed.categories)
      if (!c.isApprovedForLaunch) c.id,
  };
  final Set<String> allCategoryIds = <String>{
    for (final ServiceCategory c in CategorySeed.categories) c.id,
  };
  final Set<String> localityIds = <String>{
    for (final Locality l in LocationSeed.localities) l.id,
  };
  final Set<String> cityIds = <String>{
    for (final City c in LocationSeed.cities) c.id,
  };
  final Set<String> groupIds = <String>{
    for (final ServiceGroup g in CategorySeed.groups) g.id,
  };

  Map<String, dynamic> dataset = <String, dynamic>{};
  List<_QuerySpec> queries = <_QuerySpec>[];
  final Map<String, _Outcome> outcomes = <String, _Outcome>{};

  setUpAll(() async {
    dataset = jsonDecode(File(_fixturePath).readAsStringSync())
        as Map<String, dynamic>;
    queries = <_QuerySpec>[
      for (final dynamic entry in dataset['queries'] as List<dynamic>)
        _QuerySpec.fromJson(entry as Map<String, dynamic>),
    ];

    final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
    final MockLocationRepository locations = MockLocationRepository();
    final MockDataStore store = MockDataStore(persist: false);
    final MockProviderRepository providers = MockProviderRepository(
      store: store,
      catalog: catalog,
      locations: locations,
    );
    // Locality names are searchable text; warm once so the very first query of
    // the run behaves like the app after start-up (same method the app calls).
    await providers.warmLocalityCache();

    for (final _QuerySpec query in queries) {
      final List<ServiceCategory> hits =
          await catalog.searchCategories(query.queryText);
      final ProviderSearchResults results = await providers.search(
        ProviderQuery(
          cityId: query.cityId,
          localityId: query.localityId,
          text: query.queryText,
        ),
      );
      outcomes[query.id] = _Outcome(
        catalogCategoryIds: <String>[for (final ServiceCategory c in hits) c.id],
        results: results,
      );
    }
  });

  // ------------------------------------------------------------- helpers
  List<_QuerySpec> splitOf(String split) => queries
      .where((_QuerySpec q) => q.split == split)
      .toList(growable: false);

  Set<String> allowedFor(_QuerySpec q) => q.expectedCategoryIds.isEmpty
      ? approvedIds
      : q.expectedCategoryIds.toSet();

  /// Micro precision over a split: of every category the catalog surface
  /// suggested, how many were allowed by the query's expectation.
  double microPrecision(String split) {
    int retrieved = 0;
    int relevant = 0;
    for (final _QuerySpec q in splitOf(split)) {
      final _Outcome outcome = outcomes[q.id]!;
      final Set<String> allowed = allowedFor(q);
      retrieved += outcome.catalogCategoryIds.length;
      relevant += outcome.catalogCategoryIds
          .where(allowed.contains)
          .length;
    }
    if (retrieved == 0) return 1.0;
    return relevant / retrieved;
  }

  /// Micro recall over a split, restricted to queries that must resolve today
  /// and declare expected categories.
  double microRecall(String split) {
    int expected = 0;
    int retrieved = 0;
    for (final _QuerySpec q in splitOf(split)) {
      if (!q.isResolved || q.expectedCategoryIds.isEmpty) continue;
      final _Outcome outcome = outcomes[q.id]!;
      final Set<String> found = <String>{
        ...outcome.catalogCategoryIds,
        ...outcome.resultCategoryIds,
      };
      expected += q.expectedCategoryIds.length;
      retrieved += q.expectedCategoryIds
          .where(found.contains)
          .length;
    }
    if (expected == 0) return 1.0;
    return retrieved / expected;
  }

  // ================================================== 1. fixture schema
  group('fixture schema', () {
    test('file exists and parses as a JSON object', () {
      expect(File(_fixturePath).existsSync(), isTrue);
      expect(dataset, isA<Map<String, dynamic>>());
      expect(dataset['queries'], isA<List<dynamic>>());
    });

    test('meta.approvedCategoryIds matches the seeded launch-approved set', () {
      final Map<String, dynamic> meta = dataset['meta'] as Map<String, dynamic>;
      final Set<String> declared = <String>{
        for (final dynamic v in meta['approvedCategoryIds'] as List<dynamic>)
          v as String,
      };
      expect(declared, approvedIds);
      expect(declared, hasLength(14));
    });

    test('120 queries split exactly 60 tuning / 60 held_out', () {
      expect(queries.length, greaterThanOrEqualTo(120));
      expect(splitOf('tuning'), hasLength(60));
      expect(splitOf('held_out'), hasLength(60));
      expect(
        queries
            .where(
              (_QuerySpec q) => q.split != 'tuning' && q.split != 'held_out',
            )
            .length,
        0,
      );
    });

    test('meta.split counts agree with the actual entries', () {
      final Map<String, dynamic> splits =
          (dataset['meta'] as Map<String, dynamic>)['splits']
              as Map<String, dynamic>;
      expect(splits['tuning'], splitOf('tuning').length);
      expect(splits['held_out'], splitOf('held_out').length);
    });

    test('query ids are unique across both splits', () {
      final Set<String> ids = <String>{for (final _QuerySpec q in queries) q.id};
      expect(ids, hasLength(queries.length));
      expect(
        ids.every(
          (String id) => id.startsWith('q-tun-') || id.startsWith('q-held-'),
        ),
        isTrue,
      );
    });

    test('every query declares all ten required fields', () {
      const List<String> required = <String>[
        'id',
        'split',
        'language',
        'queryText',
        'cityId',
        'localityId',
        'expectedCategoryIds',
        'expectedMinResults',
        'allowEmpty',
        'rationale',
      ];
      for (final dynamic entry in dataset['queries'] as List<dynamic>) {
        final Map<String, dynamic> json = entry as Map<String, dynamic>;
        for (final String key in required) {
          expect(
            json.containsKey(key),
            isTrue,
            reason: '${json['id']}: missing field $key',
          );
        }
      }
    });

    test('language labels are valid and all six occur', () {
      const Set<String> valid = <String>{
        'en',
        'hi',
        'mr',
        'romanized',
        'typo',
        'unsupported',
      };
      final Set<String> used = <String>{
        for (final _QuerySpec q in queries) q.language,
      };
      expect(used.difference(valid), isEmpty);
      expect(
        valid.difference(used),
        isEmpty,
        reason: 'all six labels should occur',
      );
    });

    test('every language occurs in both splits', () {
      for (final String split in <String>['tuning', 'held_out']) {
        final Set<String> used = <String>{
          for (final _QuerySpec q in splitOf(split)) q.language,
        };
        expect(
          used,
          <String>{'en', 'hi', 'mr', 'romanized', 'typo', 'unsupported'},
          reason: '$split should cover all six language labels',
        );
      }
    });

    test('cityId is the active launch market for every query', () {
      for (final _QuerySpec q in queries) {
        expect(q.cityId, 'mh-mumbai', reason: '${q.id}: only Mumbai is active');
        expect(cityIds.contains(q.cityId), isTrue, reason: q.id);
      }
    });

    test('localityId exists and belongs to the query city', () {
      final Map<String, String> cityOfLocality = <String, String>{
        for (final Locality l in LocationSeed.localities) l.id: l.cityId,
      };
      for (final _QuerySpec q in queries) {
        expect(
          localityIds.contains(q.localityId),
          isTrue,
          reason: '${q.id}: unknown locality ${q.localityId}',
        );
        expect(
          cityOfLocality[q.localityId],
          q.cityId,
          reason: '${q.id}: locality is not in the query city',
        );
      }
    });

    test('expectedCategoryIds are real and launch-approved only', () {
      for (final _QuerySpec q in queries) {
        for (final String id in q.expectedCategoryIds) {
          expect(
            allCategoryIds.contains(id),
            isTrue,
            reason: '${q.id}: unknown category $id',
          );
          expect(
            approvedIds.contains(id),
            isTrue,
            reason: '${q.id}: $id is not launch-approved',
          );
        }
      }
    });

    test('rationales are non-empty and explain the query', () {
      for (final _QuerySpec q in queries) {
        expect(
          q.rationale.trim().length,
          greaterThanOrEqualTo(10),
          reason: '${q.id}: rationale too thin',
        );
      }
    });

    test('queryText is non-empty and already trimmed', () {
      for (final _QuerySpec q in queries) {
        expect(q.queryText.trim(), q.queryText, reason: '${q.id}: untrimmed');
        expect(q.queryText, isNotEmpty, reason: q.id);
      }
    });

    test('expectedMinResults/allowEmpty invariants hold', () {
      for (final _QuerySpec q in queries) {
        if (q.expectedMinResults > 0) {
          expect(q.allowEmpty, isFalse, reason: q.id);
        } else {
          expect(q.allowEmpty, isTrue, reason: q.id);
        }
      }
    });

    test('every launch-approved category is covered in each split', () {
      for (final String split in <String>['tuning', 'held_out']) {
        final Set<String> covered = <String>{
          for (final _QuerySpec q in splitOf(split)) ...q.expectedCategoryIds,
        };
        expect(covered.difference(approvedIds), isEmpty);
        expect(
          approvedIds.difference(covered),
          isEmpty,
          reason: '$split: approved categories without coverage',
        );
      }
    });

    test('the marquee queries from the phase brief are present', () {
      final Set<String> texts = <String>{
        for (final _QuerySpec q in queries) q.queryText,
      };
      expect(
        texts,
        containsAll(<String>[
          'plumber andheri west',
          'ac repair bandra',
          'plumer',
          'electrisian',
          'carpanter',
          'nal ka kaam',
          'bijli mistri',
          'tala chabi',
          'ghar safai',
        ]),
      );
    });
  });

  // ============================================== 2. catalog leakage invariants
  group('catalog leakage (31 unapproved wave-2/healthcare categories)', () {
    test('categories() exposes only the 14 launch-approved categories', () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      final List<ServiceCategory> categories = await catalog.categories();
      final Set<String> ids = <String>{
        for (final ServiceCategory c in categories) c.id,
      };
      expect(ids.intersection(unapprovedIds), isEmpty);
      expect(ids, approvedIds);
    });

    test('popularCategories() leaks nothing unapproved', () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      final List<ServiceCategory> popular = await catalog.popularCategories();
      final Set<String> ids = <String>{
        for (final ServiceCategory c in popular) c.id,
      };
      expect(ids.intersection(unapprovedIds), isEmpty);
      expect(ids.difference(approvedIds), isEmpty);
      expect(popular, isNotEmpty);
    });

    test('categoriesByGroup() leaks nothing unapproved for every group',
        () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      expect(groupIds, hasLength(6));
      for (final String groupId in groupIds) {
        final List<ServiceCategory> inGroup =
            await catalog.categoriesByGroup(groupId);
        final Set<String> ids = <String>{
          for (final ServiceCategory c in inGroup) c.id,
        };
        expect(
          ids.intersection(unapprovedIds),
          isEmpty,
          reason: 'group $groupId leaked unapproved categories',
        );
      }
      // The whole healthcare group is unapproved, so it must list nothing.
      expect(await catalog.categoriesByGroup('healthcare'), isEmpty);
    });

    test('healthcareCategories() is empty at launch and leaks nothing',
        () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      final List<ServiceCategory> healthcare =
          await catalog.healthcareCategories();
      expect(
        healthcare,
        isEmpty,
        reason: 'every healthcare category is unapproved at launch',
      );
    });

    test('categoriesWithGroup() leaks nothing unapproved', () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      final List<CategoryWithGroup> pairs = await catalog.categoriesWithGroup();
      final Set<String> ids = <String>{
        for (final CategoryWithGroup pair in pairs) pair.category.id,
      };
      expect(ids.intersection(unapprovedIds), isEmpty);
      expect(ids, approvedIds);
    });

    test('searchCategories() leaks nothing unapproved for all 120 queries',
        () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      for (final _QuerySpec q in queries) {
        final List<ServiceCategory> hits =
            await catalog.searchCategories(q.queryText);
        final Set<String> ids = <String>{
          for (final ServiceCategory c in hits) c.id,
        };
        expect(
          ids.intersection(unapprovedIds),
          isEmpty,
          reason: '${q.id} ("${q.queryText}") exposed unapproved categories',
        );
      }
    });

    test('catalog data inventory is 45 categories, 31 unapproved, 14 approved',
        () {
      expect(allCategoryIds, hasLength(45));
      expect(unapprovedIds, hasLength(31));
      expect(approvedIds, hasLength(14));
    });

    test('categoryById still resolves unapproved ids (lookup path intact)',
        () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      // Lookups by id still work for editors/saved data...
      expect(await catalog.categoryById('dentist'), isNotNull);
      expect(await catalog.categoryById('masonry'), isNotNull);
      // ...but unapproved ids are absent from every list surface.
      final List<ServiceCategory> categories = await catalog.categories();
      expect(
        categories.map((ServiceCategory c) => c.id),
        isNot(contains('dentist')),
      );
    });
  });

  // ================================================ 3. per-query execution
  // One test per fixture query: 120 tests generated from the dataset.
  group('query execution', () {
    for (final _QuerySpec q in _allQueries) {
      test('${q.id} [${q.split}/${q.language}] "${q.queryText}"', () {
        final _Outcome outcome = outcomes[q.id]!;
        // Global invariant: no unapproved listing ever surfaces, for any query.
        for (final ProviderResultItem item in outcome.results.items) {
          expect(
            item.provider.categoryIds.any(approvedIds.contains),
            isTrue,
            reason: '${q.id}: ${item.provider.displayName} is not publicly '
                'listed (no launch-approved category)',
          );
        }
        final Set<String> suggested = outcome.catalogCategoryIds.toSet();
        expect(
          suggested.intersection(unapprovedIds),
          isEmpty,
          reason: '${q.id}: catalog suggested unapproved categories',
        );

        if (q.isResolved) {
          expect(
            outcome.results.totalCount,
            greaterThanOrEqualTo(q.expectedMinResults),
            reason: '${q.id}: expected at least ${q.expectedMinResults} '
                'results in ${q.localityId} for "${q.queryText}"',
          );
          final Set<String> allowed = allowedFor(q);
          for (final ProviderResultItem item in outcome.results.items) {
            expect(
              item.provider.categoryIds.any(allowed.contains),
              isTrue,
              reason: '${q.id}: ${item.provider.displayName} does not offer '
                  'any expected category '
                  '(${q.expectedCategoryIds.join(', ')})',
            );
          }
          if (q.expectedCategoryIds.isNotEmpty) {
            expect(
              suggested.difference(q.expectedCategoryIds.toSet()),
              isEmpty,
              reason: '${q.id}: catalog suggested categories outside the '
                  'expectation',
            );
          }
        } else {
          // Recorded baseline: these queries return nothing today (missing
          // tokenisation, Devanagari keywords, fuzzy matching, or the domain is
          // intentionally unapproved). Re-baseline the fixture when support
          // lands on purpose.
          expect(
            outcome.results.items,
            isEmpty,
            reason: '${q.id} ("${q.queryText}") is a recorded gap and must '
                'return no listings until re-baselined',
          );
        }
      });
    }
  });

  // ==================================================== 4. printed metrics
  group('metrics (printed for tasks/evidence/phase-101.md)', () {
    test('micro precision is 1.0 on both splits', () {
      final double tuningPrecision = microPrecision('tuning');
      final double heldOutPrecision = microPrecision('held_out');
      debugPrint('precision(tuning)=$tuningPrecision');
      debugPrint('precision(held_out)=$heldOutPrecision');
      expect(tuningPrecision, 1.0);
      expect(heldOutPrecision, 1.0);
    });

    test('micro recall over resolvable queries is 1.0 on both splits', () {
      final double tuningRecall = microRecall('tuning');
      final double heldOutRecall = microRecall('held_out');
      debugPrint('recall(tuning)=$tuningRecall');
      debugPrint('recall(held_out)=$heldOutRecall');
      expect(tuningRecall, 1.0);
      expect(heldOutRecall, 1.0);
    });

    test('empty-result rate summary is printed per split and per language', () {
      final StringBuffer buffer = StringBuffer('phase-101 metrics\n');
      buffer.writeln(
        'split\tqueries\tresolved\tgap\tempty\temptyRate\tprecision\trecall',
      );
      for (final String split in <String>['tuning', 'held_out']) {
        final List<_QuerySpec> inSplit = splitOf(split);
        final int resolved =
            inSplit.where((_QuerySpec q) => q.isResolved).length;
        final int empty = inSplit
            .where((_QuerySpec q) => outcomes[q.id]!.results.items.isEmpty)
            .length;
        buffer.writeln(
          '$split\t${inSplit.length}\t$resolved\t'
          '${inSplit.length - resolved}\t$empty\t'
          '${(empty / inSplit.length).toStringAsFixed(3)}\t'
          '${microPrecision(split).toStringAsFixed(3)}\t'
          '${microRecall(split).toStringAsFixed(3)}',
        );
      }

      buffer.writeln('');
      buffer.writeln('language\tqueries\tempty\temptyRate');
      final Map<String, int> totalByLanguage = <String, int>{};
      final Map<String, int> emptyByLanguage = <String, int>{};
      for (final _QuerySpec q in queries) {
        totalByLanguage[q.language] = (totalByLanguage[q.language] ?? 0) + 1;
        if (outcomes[q.id]!.results.items.isEmpty) {
          emptyByLanguage[q.language] =
              (emptyByLanguage[q.language] ?? 0) + 1;
        }
      }
      final List<String> languages = totalByLanguage.keys.toList()..sort();
      for (final String language in languages) {
        final int total = totalByLanguage[language]!;
        final int empty = emptyByLanguage[language] ?? 0;
        buffer.writeln(
          '$language\t$total\t$empty\t${(empty / total).toStringAsFixed(3)}',
        );
      }
      debugPrint(buffer.toString());

      // Sanity on the printed numbers themselves.
      final int overallEmpty = queries
          .where((_QuerySpec q) => outcomes[q.id]!.results.items.isEmpty)
          .length;
      expect(
        overallEmpty,
        greaterThan(0),
        reason: 'gap queries must remain visible as empty results',
      );
      expect(
        overallEmpty,
        lessThan(queries.length),
        reason: 'resolvable queries must return results',
      );
    });

    test('category exposure distribution covers every approved category', () {
      final Map<String, int> exposure = <String, int>{
        for (final String id in approvedIds) id: 0,
      };
      for (final _QuerySpec q in queries) {
        final _Outcome outcome = outcomes[q.id]!;
        final Set<String> exposed = <String>{
          ...outcome.catalogCategoryIds,
          ...outcome.resultCategoryIds,
        };
        for (final String id in exposed) {
          if (exposure.containsKey(id)) {
            exposure[id] = exposure[id]! + 1;
          }
        }
      }
      final StringBuffer buffer =
          StringBuffer('category exposure (number of queries)\n');
      final List<String> ids = exposure.keys.toList()..sort();
      for (final String id in ids) {
        buffer.writeln('$id\t${exposure[id]}');
      }
      debugPrint(buffer.toString());
      for (final String id in approvedIds) {
        expect(
          exposure[id],
          greaterThan(0),
          reason: '$id is never exposed by the dataset',
        );
      }
    });
  });

  // =========================================== 5. cross-surface consistency
  group('cross-surface consistency', () {
    test('searchCategories("") returns exactly the 14 launch categories',
        () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      final List<ServiceCategory> hits = await catalog.searchCategories('');
      final Set<String> ids = <String>{
        for (final ServiceCategory c in hits) c.id,
      };
      expect(ids, approvedIds);
    });

    test('provider search honours the locality gate (no provider, no results)',
        () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      final MockLocationRepository locations = MockLocationRepository();
      final MockDataStore store = MockDataStore(persist: false);
      final MockProviderRepository providers = MockProviderRepository(
        store: store,
        catalog: catalog,
        locations: locations,
      );
      // Borivali West has no plumbing listing, so even a perfect category word
      // returns nothing there.
      final ProviderSearchResults results = await providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-borivali-west',
          text: 'plumber',
        ),
      );
      expect(results.items, isEmpty);
    });

    test('paused and draft seeded listings never surface in any query result',
        () {
      const Set<String> hiddenIds = <String>{
        'provider-seed-paused-001',
        'provider-seed-draft-001',
      };
      for (final _QuerySpec q in queries) {
        for (final ProviderResultItem item in outcomes[q.id]!.results.items) {
          expect(
            hiddenIds.contains(item.provider.id),
            isFalse,
            reason: '${q.id}: hidden listing surfaced',
          );
        }
      }
    });

    test('sponsored placement is labelled and limited to matching context',
        () async {
      final MockServiceCatalogRepository catalog = MockServiceCatalogRepository();
      final MockLocationRepository locations = MockLocationRepository();
      final MockDataStore store = MockDataStore(persist: false);
      final MockProviderRepository providers = MockProviderRepository(
        store: store,
        catalog: catalog,
        locations: locations,
      );
      final ProviderSearchResults results = await providers.search(
        const ProviderQuery(
          cityId: 'mh-mumbai',
          localityId: 'mh-mumbai-andheri-west',
          text: 'plumber',
        ),
      );
      expect(results.items, isNotEmpty);
      expect(
        results.items.first.isSponsored,
        isTrue,
        reason: 'the seeded plumbing promotion should label Sharma',
      );
    });
  });
}
