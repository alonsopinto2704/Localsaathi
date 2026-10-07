# Phase 101 Evidence — Search evaluation dataset & multilingual relevance suite

**Status:** Done (gates passed: `flutter analyze` 0 issues; `flutter test` 152/152 pass)

## Objective

Turn the launch-category boundary and the everyday-language search promise into an executable, measured spec:

1. `MockServiceCatalogRepository.searchCategories` must search only `_launchCategories` (`isApprovedForLaunch == true`), matching SQL `public.search_categories` (migration `20261006000016_public_projection.sql` lines 403–429: filter `sc.is_approved_for_launch`, name/keyword containment).
2. A 120-query, Mumbai, multilingual evaluation dataset (60 `tuning` + 60 `held_out`) that covers all 14 launch-approved pilot categories, six language labels (English, Devanagari Hindi, Devanagari Marathi, romanized Hinglish/Marathi, typos, unsupported domains) and pins the "0 unapproved listings" rule for wave-2/healthcare queries.
3. A 152-test suite that validates the fixture schema, asserts zero unapproved-category leakage through every catalog surface, executes every query against the mock repositories, and prints precision/recall/empty-result-rate/exposure metrics as the phase 102+ improvement baseline.

## Prerequisites

- `tasks/evidence/phase-009.md` — the corrected 14-pilot / 31-unapproved category matrix (45 categories total). This file is the source of truth for which categories may surface; the phase brief's slug list (`ac_repair`, `mehndi`, `salon_at_home`, `tutoring`, …) predates the corrected taxonomy, so the dataset follows the seed (`category_seed.dart`) instead: see "Taxonomy reconciliation" below.
- `tasks/evidence/audit-2026-10-07-followup.md` — the applied rule that the mock hides listings without a launch-approved category (`MockDataStore.isListed`), which the "0 unapproved listings" expectations rely on.
- `backend/supabase/migrations/20261006000016_public_projection.sql` — SQL `search_categories` semantics mirrored by the mock.

## Changed paths

- `lib/data/repositories/mock_service_catalog_repository.dart` — `searchCategories` (lines 94–119) now searches `_launchCategories` instead of `_categories`; both the empty-needle fast path (returns the 14 launch categories) and the match loop are launch-filtered. One formatting-only fix in the same file (`_groups` initializer, lines 12–17, pre-existing `require_trailing_commas` finding) so the mandated analyze command passes with 0 issues. No behaviour change outside `searchCategories`.
- `test/fixtures/search_evaluation_dataset.json` — new fixture, 120 labelled queries.
- `test/multilingual_search_eval_test.dart` — new suite, 152 tests.
- `tasks/evidence/phase-101.md` — this file.

## Taxonomy reconciliation (why the dataset's 14 differ from the phase brief)

The seed and phase-009's corrected matrix define the launch-approved set:

`plumbing`, `electrical`, `carpentry`, `painting`, `ac-repair`, `appliance-repair`, `home-cleaning`, `pest-control`, `laundry-ironing`, `water-tank-cleaning`, `mechanic`, `computer-repair`, `mobile-repair`, `tailoring` (14 approved; 31 unapproved = 24 wave-2 + 7 healthcare).

The phase brief's list (`waterproofing`, `locksmith`, `packers_movers`, `mehndi`, `salon_at_home`, `tutoring`) names wave-2 categories in the current seed — `mehndi`/`salon_at_home` map to `beauty-at-home`, which is unapproved. The dataset therefore covers the *actual* 14 approved categories (every one of them appears as `expectedCategoryIds` in both splits) and additionally pins `mehndi`, `tala chabi`, `tutor`, `packers and movers`, `salon at home` as **unsupported** queries that must return nothing and leak nothing.

## Commands and results

```
C:\Users\alonso\flutter\bin\flutter.bat analyze lib/data/repositories/mock_service_catalog_repository.dart test/multilingual_search_eval_test.dart
→ No issues found! (ran in 8.9s)  EXIT=0

C:\Users\alonso\flutter\bin\flutter.bat test --no-pub test/multilingual_search_eval_test.dart
→ 00:00 +152: All tests passed!  EXIT=0
```

Suite composition (152 tests): 16 fixture-schema + 8 catalog-leakage + 120 per-query execution + 4 metric + 4 cross-surface consistency.

### Measured metrics (printed by the suite; 2026-10-07 run)

Definitions: *resolved* = query with `expectedMinResults > 0` (hard expectation); *gap* = recorded-empty query (`allowEmpty: true`); precision/recall are micro-averaged — precision over every category the catalog suggested (`retrieved ∩ allowed / retrieved`), recall over resolvable queries with expected categories (`expected ∩ retrieved / expected`, retrieved = catalog suggestions ∪ result-listing categories).

| Split | Queries | Resolved | Gap | Empty results | Empty rate | Precision | Recall |
|---|---|---|---|---|---|---|---|
| tuning | 60 | 32 | 28 | 28 | 0.467 | 1.000 | 1.000 |
| held_out | 60 | 23 | 37 | 37 | 0.617 | 1.000 | 1.000 |
| **Overall** | **120** | **55** | **65** | **65** | **0.542** | **1.000** | **1.000** |

Empty-result rate by language (the phase 102+ improvement map):

| Language | Queries | Empty | Empty rate | Reading |
|---|---|---|---|---|
| en | 54 | 3 | 0.056 | Only the multi-token locality+service and "near me" phrases fail |
| hi (Devanagari) | 18 | 18 | 1.000 | No Devanagari keywords are seeded — everything fails today |
| mr (Devanagari) | 13 | 13 | 1.000 | Same as hi |
| romanized | 12 | 8 | 0.667 | 4/12 resolve (`nal`, `safai`, `dhobi`, `darzi`); multi-token phrases fail |
| typo | 8 | 8 | 1.000 | No fuzzy/trigram matching on the client |
| unsupported | 15 | 15 | 1.000 | Correct-by-design: wave-2/healthcare domains return nothing and leak nothing |

Category exposure distribution (number of queries, both splits, that expose the category via catalog suggestion or result listings):

| Category | Queries | Category | Queries |
|---|---|---|---|
| plumbing | 11 | mechanic | 3 |
| home-cleaning | 11 | tailoring | 3 |
| computer-repair | 7 | water-tank-cleaning | 3 |
| electrical | 6 | ac-repair | 4 |
| pest-control | 6 | mobile-repair | 4 |
| appliance-repair | 5 | carpentry | 4 |
| painting | 5 | laundry-ironing | 5 |

All 14 approved categories are exposed (asserted in both splits); no unapproved category is exposed anywhere (asserted for all six surfaces × every query).

### Two mid-run corrections (kept visible on purpose)

1. `q-tun-015 "cleaning"` initially expected `[home-cleaning]` only; `search_categories`-style containment also matches the *name* "Water tank cleaning" (an approved category), so the expectation was corrected to `[home-cleaning, water-tank-cleaning]`. This is exactly the kind of recall/precision detail the dataset exists to pin.
2. The pre-existing `require_trailing_commas` info at `mock_service_catalog_repository.dart:14` (present at HEAD, outside the searchCategories body) was reformatted so the mandated analyze gate is 0-issue. Formatting only; the diff is one cascade re-indent.

## Security/privacy effect

- **Launch-boundary enforcement:** `searchCategories` previously exposed wave-2/healthcare categories (e.g. "dentist", "nurse", "locksmith", "packers") to customers on the home/search/category surfaces. It now matches SQL `public.search_categories`: only the 14 approved categories can be suggested, keyed by any query. The suite turns that into 8 explicit leakage tests × 120 query texts plus 6 surface invariants.
- **"0 unapproved listings":** for every dataset query, any returned listing must offer at least one launch-approved category (mirrors `MockDataStore.isListed` / SQL `is_publicly_listed`); paused/draft seeded listings are asserted absent from all 120 result sets; the locality gate is asserted to hide providers that do not serve the customer's locality.
- **Privacy:** the fixture contains synthetic, fictional queries only — no real person, phone number, or address; localities are public reference names from the seed. No PII, no network access (the suite is fully offline against in-memory mocks).

## Residual risks

- **Multi-token tokenisation gap (known, measured):** `plumber andheri west`, `ac repair bandra`, `electrician near me` return empty today — the matcher is substring-based over the whole needle. En 0.056 / overall 0.542 empty rate is the baseline phase 102 tokenisation must beat. Re-baseline the affected fixture rows when it lands.
- **Devanagari and typos are 100% unresolved today** (`hi`/`mr`/`typo` empty rates 1.000). No transliteration, no Devanagari keywords, no fuzzy matching. Same re-baselining rule.
- **Mock/SQL divergence by design:** the mock ranks name-matches above keyword matches and supports phrase keywords the SQL side also supports via containment; both filter `is_approved_for_launch`. A future SQL-side trigram similarity (`%`) would diverge from the mock's strict substring — evaluate both together in phase 102.
- **Metrics are mock-relative:** the eval measures the mock repositories, not a live backend; SQL parity is asserted structurally (same filter, same containment), not against a running Postgres.

## Rollback procedure

1. Revert the single behaviour change: `git checkout HEAD -- lib/data/repositories/mock_service_catalog_repository.dart` loses the `_launchCategories` fix (and the formatting fix) — search again leaks unapproved categories, so pair any revert with reverting this whole phase.
2. Remove the suite: delete `test/multilingual_search_eval_test.dart` and `test/fixtures/search_evaluation_dataset.json` (self-contained; nothing imports them).
3. Delete `tasks/evidence/phase-101.md`. No other file depends on it (the fixture is read only by its suite; `docs/backend-contract.md` was not edited in this phase).

## Reviewer

Pending (human sign-off, same status as phases 001–040 gates).

## Next action

1. Phase 102 (search quality): tokenise multi-word queries, seed Devanagari keywords for the 14 approved categories (hi + mr), add fuzzy (trigram/edit-distance) matching for typos — then re-baseline the 65 gap rows in `test/fixtures/search_evaluation_dataset.json` and update the tables above.
2. Feed the exposure distribution to phase 102's keyword-priority ordering: `plumbing`/`home-cleaning`/`computer-repair` dominate; `mechanic`/`tailoring`/`water-tank-cleaning` are the thinnest (3 queries each) — add one more query each if their keywords change.
