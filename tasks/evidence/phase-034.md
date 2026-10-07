# Phase 034 — Search resource bounds

**Status:** In review. Verified locally (PGlite); latency evidence is in phase 038. · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Cap text, filters, arrays, pagination and sort before any expensive work, and prevent wildcard expansion.

## Changed paths
Migration `…16`:
- `search_providers`, `search_cities`, `search_categories`;
- `similar_providers`, `providers_published_in_city`;
- `private.like_contains` (new).

## Bounds
| Input | Bound |
|---|---|
| Search text | ≤80 characters (`validation_failed`). `%`, `_` and `\` are matched literally. |
| Category / locality filters | ≤20 each |
| `p_limit` | Clamped to 1–50. It was unbounded: the audit got 121 of 121 rows with `p_limit=100000`. |
| `p_offset` | ≤500 (`validation_failed`: "refine the search") |
| Sort order | Fixed server-side, with a deterministic tie-break on `id` |
| Other result caps | `similar_providers` ≤12; `providers_published_in_city` ≤500; city and category search ≤50 rows |

Two related decisions:
- **Statement timeout.** A function-level `SET statement_timeout` does not interrupt the statement that is already running. Search therefore relies on Supabase's role timeouts (anon 3 s and authenticated 8 s by default). Confirm these in the project settings at deployment.
- **Pagination.** A bounded offset is enough at launch scale. Keyset pagination is added only if phase 038 measurements require it.

## Verification
- `0012_search_bounds` (21 assertions):
  - 81 characters, 21 categories and offset 501 are each rejected;
  - limit 100000 returns at most 50 items;
  - `A_B%C` is found literally;
  - `%` does not match every provider;
  - all 13 working-hours fixture cases.
- Suite: `Tests: 14/14 files passed, 149/149 assertions passed. PASS`.

## Rollback
Restore a simpler bounded query (plan). The bounds themselves stay.
