# Phase 038 — Database performance evidence

**Status:** In review. Measured in PGlite; hosted-Postgres latency is not measured. · **Author/reviewer:** Opus chief engineer, 2026-10-07 (a Sonnet worker built the harness and took the first measurements, then hit a usage limit; the reviewer finished the phase) · **Second human reviewer:** pending (phase 040)

## Objective
Measure search and dashboards at expected and stress scale with labelled synthetic data. Add only indexes whose read gain is measured, and record their write and storage cost. Relevance must not change unnoticed.

## Changed paths
- `backend/scripts/bench-search.mjs` (new, by the worker). It inserts set-based SYNTHETIC data:
  - `SYNTH …` names and `+9199…` phones;
  - 1–3 categories, 1–4 service areas, 7 hours rows and 0–5 photos per provider;
  - about 5% suspended and 10% paused.
  It then runs 200 (or `--calls N`) anon calls per query. It supports `--baseline` (old migrations only), `--extra-sql` (candidate index, benchmark DB only) and `--json`.
- `backend/supabase/migrations/20261006000020_measured_indexes.sql` (new):
  - `idx_provider_photos_provider`;
  - the set-based view `private.listed_providers`, now the single definition of "publicly listed";
  - `is_publicly_listed`, `provider_count_by_locality` and `providers_published_in_city` rewritten on top of that view.

## Results: p95 in ms, anon, PGlite (WASM, single process)
| Query | Baseline 5k | Hardened 5k (no index) | **Final 5k** | Baseline 50k | Hardened 50k (no index) | **Final 50k** |
|---|---|---|---|---|---|---|
| Locality only | 610 | 585 | **144** | 55,213 | 65,024 | **221** |
| Locality + category | 48 | 52 | **69** | 2,648 | 2,691 | **131** |
| Text "plumb" | 196 | 194 | **193** | 7,883 | 8,412 | **404** |
| Text matching nothing | 48 | 45 | **159** | 418 | 630 | **261** |
| Open now only | 83 | 96 | **187** | 3,818 | 4,017 | **259** |
| Page 10 (limit 50, offset 450) | 554 | 541 | **12** | — | 54,376 | **317** |
| `p_limit` 50 | 692 | 676 | **23** | — | 55,822 | **184** |
| `get_public_profile` | 4 | 4 | **0.5** | — | 25 | **1.3** |
| `provider_count_by_locality` | 34 | 365 | **111** | — | 4,009 | **209** |
| `providers_published_in_city` | 11,019* | 1,639 | **195** | — | 14,935 | **361** |

Notes on the columns:
- **Final** = all migrations through `…20`, with the current code-reviewed search. The 50k final column comes from `--calls 30`.
- \*The baseline returned **every** listing in the city, unbounded. The hardened version caps it at 500.
- The baseline 50k run was stopped after its first five queries by the worker's session limit (log: `scratchpad/phase038/b50000.log`).
- Row counts at 50k: 50,000 providers, 41,212 publicly eligible, 125k service areas, 350k hours rows, 125k photos. Locality-only matches: 2,424 hardened. The baseline counts more, because it included listings without consent or with un-approved categories.
- The final 50k run inserted all 50,000 providers (checked from its JSON counts).

**Target** (plan): database search p95 under 800 ms at the documented load.
- **Met in PGlite at both 5k and 50k** after the changes: the worst p95 is 404 ms.
- Before the changes, the stress scale **missed by up to 80×**, on both the baseline and the hardened schema.

## Root causes found by measurement
1. **No index on `provider_photos(provider_id)`.** Search ranks every match by photo count and builds photo arrays per listing. Each lookup scanned all 125k photos. That one btree took locality-only search at 50k from p95 65,024 ms to under 450 ms. Measured by the worker with `--extra-sql idx-photos.sql`, before the reviewer's view change.
   - **Cost:** about 2.2 MB at 125k photos (`pg_relation_size`), plus one index entry per photo insert or delete. Photos are capped at 5 per listing, so write overhead is negligible.
2. **Per-row predicate calls.** The list endpoints called the SECURITY DEFINER `is_publicly_listed()` once per row: about 1.2 s each at 50k.
   - The rule now lives once, in the view `private.listed_providers`. The planner joins it set-based.
   - `count_by_locality` went from 1,202 to 209 ms, and `published_in_city` from 1,158 to 361 ms (p95, 50k).
   - There is still exactly one definition of "publicly listed". The code review had flagged an inline duplicate as drift risk, and this resolves it.

## Semantics check
- No relevance change from the indexes or the view. The suite (`node backend/scripts/verify-db.mjs` → `Tests: 14/14 files passed, 151/151 assertions passed. PASS`) includes:
  - ordering (sponsored first, deterministic `id` tie-break);
  - eligibility on every discovery path (0010 and 0014);
  - bounds (0012).
- Result counts differ from the baseline by design: listings without consent or with un-approved categories are excluded.

## Plans
EXPLAIN (ANALYZE, BUFFERS) outputs for locality+category, text "plumb", locality-only ranking and `public_profile_json` ×20, at 5k and 50k: `scratchpad/phase038/*.txt` (session scratchpad, not committed).
- Before the index, the plans show a `Seq Scan on provider_photos` inside the per-match `SubPlan`.
- With the index, they show an `Index Only Scan using idx_provider_photos_provider`.

## Caveats
- **PGlite is not production.** It is single-process WASM Postgres with no concurrency and no network. Absolute numbers are not hosted Supabase latency; they show relative cost and plan shape.
- **Repeat on hosted Postgres.** Re-run on the disposable Supabase project (phase 006) and again at launch load (phase 271).
- **Statement timeouts.** Role timeouts (anon 3 s, authenticated 8 s) remain the backstop (phase 034).

## Rollback
Drop `idx_provider_photos_provider` through a reviewed migration (plan). The view can be replaced by a function with the same signature.
