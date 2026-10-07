# Phase 040 — Trusted backend gate

**Status:** Done (locally). **Passed for the database layer, with blockers recorded.** Production writes stay disabled until the HTTP pack passes on a real Supabase project. · **Reviewer:** Opus chief engineer, 2026-10-07 · **Second reviewer:** independent red-team agent (`phase-040-redteam.md`) · **Human sign-off:** pending (product owner / backend-security engineer)

## What the gate requires (plan) and the evidence
| Requirement | Evidence | Result |
|---|---|---|
| Review grants | Catalog inventory before/after (phase 021). anon EXECUTE went from 61 functions to 12; anon table writes from all 23 tables to none. | Pass |
| Field projection | Allowlisted `public_profile_json` (phase 022); a key-set test survives adding a new column. | Pass |
| Lifecycle controls | Publication invariants, consent withdrawal, revision, deletion/retention, audit (phases 027, 030, 032, 035, 036). | Pass (Edge Function unexecuted) |
| Query bounds | Phase 034 bounds. Phase 038: worst p95 404 ms at 50k listings (PGlite). | Pass (hosted latency unmeasured) |
| Platform-level tests | HTTP pack written (phase 039); self-test proves a forbidden-field regression fails it. | **Blocked**: no Docker or Supabase project |
| Second reviewer reproduces the highest-impact disclosure and ownership cases | Independent red team wrote its own probes (no access to the pgTAP suites) on 1,504 published synthetic listings. | **6/6 mandatory cases HELD, 0 BROKEN** |
| No unresolved critical authorization leak | See the findings table below. | Pass (no critical or high finding open) |
| Recovery steps executable | Migration rehearsal 18/18, including an injected mid-migration failure and recovery (phase 037). | Pass (locally) |

## Final verification (2026-10-07)
- `node backend/scripts/verify-db.mjs` → `Tests: 14/14 files passed, 151/151 assertions passed. PASS`
- `node backend/scripts/rehearse-migrations.mjs --providers 1000` → `Rehearsal: 18/18 checks passed`
- `node backend/scripts/http-authz-pack.mjs --self-test` → `SELF-TEST PASSED` (exit 0). The real run exits 2 without config and refuses any service-role key.
- Mutation checks: 4 injected authorization regressions each failed the suite with exit 1 (phase 025).
- `flutter analyze` → 71 info-level issues, 0 errors. `flutter test --no-pub` → +74 ~1 −10 (the same 10 failures as before this work; tracked from phase 005).

## Findings ledger for phases 021–040 (all reviewers)
| # | Finding | Found by | Severity | State |
|---|---|---|---|---|
| 1 | anon read raw published rows (phone regardless of consent, user_id, exact pin, suspension reason) | Phase 013 / audit probe | Critical | Fixed (…13, …17) |
| 2 | Every function executable by PUBLIC/anon, incl. owner-shaped JSON for any id | Inventory | High | Fixed (…13) |
| 3 | "Squatter": a signed-in user publishes a listing with someone else's phone | Audit probe | High | Fixed (no insert grant; RPC only) |
| 4 | Signed-in users could still read every published row raw via the 0009 policy | Reviewer, after …13 | High | Fixed (…17) |
| 5 | Phones stored without `+` (GoTrue format) | Reviewer | Medium | Fixed (…15 + backfill) |
| 6 | First …15 would fail to apply on any real DB with registrations | Rehearsal | High (deploy) | Fixed (backfill) |
| 7 | Publishing a never-consented draft silently became "paused" | Test worker | Medium | Fixed |
| 8 | Audit redaction rejected UUIDs (~0.35% of providers un-moderatable) | /code-review | High | Fixed |
| 9 | Spoofable leftmost XFF; all header-less guests in one bucket | /code-review | Medium | Fixed |
| 10 | Owner RPCs let admins silently edit provider content | Phase 039 worker | Medium | Fixed (owner-only) |
| 11 | Search p95 65 s at 50k (missing photos index); list paths ~1.2 s | Phase 038 | High (availability) | Fixed (…20) |
| 12 | Consent RPCs unthrottled (F2); photo changes skip revision (F3) | Red team | Low | Fixed (…21), tests in `0014` |
| 13 | Rate limits trust `cf-connecting-ip`/`x-forwarded-for` if nothing in front overwrites them (F1) | Red team | Medium **if** exposed without a trusted edge | **Open: deployment verification.** Hosted Supabase sits behind its edge. Confirm with the HTTP pack: send a spoofed `cf-connecting-ip` 6× and expect `rate_limited`. Until then the per-listing caps (50 reports/day) bound the damage. |
| 14 | pgcrypto/pg_trgm functions in `extensions` executable by anon (F4) | Red team | Info | Accepted: `extensions` is not in the PostgREST exposed schemas (`config.toml`). Revisit if exposed schemas change. |

## Blockers carried forward (owner → next action)
| Blocker | Owner | Next action |
|---|---|---|
| Full-stack parity and HTTP pack (phases 006, 039) | Product owner: install Docker Desktop, or create a disposable Supabase project | Run `supabase start`, apply migrations, create the 3 test users, and run `node backend/scripts/http-authz-pack.mjs`. Include the F1 header-spoof probe. |
| delete-account Edge Function unexecuted | Integration engineer | Deploy to the disposable project and delete a test account that has photos; confirm the bucket is empty. |
| `purge_expired_records` schedule | Integration engineer | pg_cron daily job in the project (deployment). |
| Hosted latency | Integration engineer | Re-run `bench-search.mjs`-equivalent calls against the project (phase 271 at launch load). |
| Version control | Product owner | `git init` and a baseline commit. All of this work currently lives only in the working tree plus a temporary tarball. |
| Flutter has no Supabase adapters yet | Phase 061+ | Must use the RPC contract (`docs/backend-contract.md`) and send `expectedRevision`/`idempotencyKey`. |

## Decision
The database layer is trusted to proceed to Workstream 3 (identity, phases 041+) and Workstream 4 (live adapters). **Production writes stay disabled** (plan safe-stop) until the HTTP pack passes against a real project and a human backend/security reviewer signs this file.

## 2026-10-07 audit follow-up
See `tasks/evidence/audit-2026-10-07-followup.md`. Migration `0022` closes the audit's P0 findings (owner id in photo paths, publication invariant on edit, credential path, cleanup race, audit redaction, unaudited admin writes) plus P1 validation/revision/rate-limit items; DB suite 16/16 files, 172/172. Deferred items are listed in the follow-up file.
