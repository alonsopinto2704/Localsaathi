# Phase 064 Evidence - Live service catalog

**Status:** Done locally. Staging check BLOCKED (no hosted project). **Reviewer:** pending.

## Objective
Groups, categories, keywords, ordering and icons from the existing public-read contract; retired categories tolerated in old links but never offered for new use.

## Changed paths
- lib/data/live/live_service_catalog_repository.dart (new)
- test/live_repositories_test.dart (group "phase 064")

## Behaviour
- `service_groups` / `service_categories` loaded once, cached 15 minutes (stale copy on failure, `isStale`), ordered by group sort order then category sort order; stable ids untouched.
- Lists (categories, by group, popular, healthcare, with-group) include only categories whose `is_approved_for_launch` is explicitly true (missing flag = not approved).
- `categoryById` / `categoriesByIds` still resolve retired categories so saved profiles and old links keep their name; `isApprovedForLaunch` stays false. The server (publish trigger) is what refuses a new publication; the client never offers them.
- `searchCategories` -> bounded `search_categories` RPC (text <= 80), then re-resolved against the catalog so a hit can never be less strict than a list.
- Unknown icon keys pass through (the icon resolver has a generic fallback); a missing key becomes `other`. Names are single-language data: no localisation fallback exists yet.

## Commands run (actual results)
- `flutter test --no-pub test/live_repositories_test.dart --plain-name "phase 064" -r failures-only` -> `+5: All tests passed!`
- Final full run: `+408: All tests passed!`; `flutter analyze` -> `73 issues found.` (baseline 73)

## Acceptance
| Requirement | Evidence | Result |
|---|---|---|
| Data-driven catalog edits appear correctly | test: ordering, popular, healthcare flags from rows | Pass (local) |
| Retired categories cannot be newly published | not offered by any list or search (tested); server-side refusal is backend phase work, not exercised here | Client Pass; server BLOCKED (no DB run) |
| Unknown icon keys / old links | tested | Pass |
| Staging check | not performed | BLOCKED |

## Remaining uncertainty
- Onboarding category pickers must use `categories()` (they do via the interface); an editor that pre-selects a retired category will show it by id lookup only.
- No localisation fallback chain (single-language names).

## Next action
Persist the catalog with its revision for offline start; add localized names when the schema has them.
