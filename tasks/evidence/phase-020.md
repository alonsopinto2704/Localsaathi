# Phase 020 — Foundation gate and scope freeze

**Status:** Done. Gate passed with recorded blockers; re-verified 2026-10-07 after the deep audit. · **Reviewer:** Opus chief engineer, 2026-10-06 · **Human sign-off:** pending (product owner)

## Objective
Review the phase 001–019 evidence, freeze core-release expectations, and give every open decision an owner and next step.

## Evidence review

| Phase | Status | Review outcome |
|---|---|---|
| [001](phase-001.md) Inventory | Accepted | Test counts corrected by reviewer (PGlite 17/17 after 004; Flutter counts come from 005). |
| [002](phase-002.md) Customer journey | Accepted + fix | Browser walkthrough at 375 px. **Marathi/Hindi crash fixed** (missing Material localizations; +3 tests, 0 console errors after). Trust copy "verified plumbers…" and truncated category labels recorded. |
| [003](phase-003.md) Provider journey | Accepted with correction | Account-switch draft leak (incl. phone number) **reproduced by execution** (`test/account_switch_draft_test.dart`, skipped until 049/051). |
| [004](phase-004.md) DB runner repair | **Done** | Re-run by reviewer: 5/5 suites, 17/17 assertions, exit 0. Fixtures only; no trigger/RLS weakened. Line endings normalised to LF. |
| [005](phase-005.md) Flutter baseline | Accepted | Flutter 3.47.6 / Dart 3.13.5; analyze 71 infos, 0 errors; reviewer re-run **58 pass / 10 fail** (all in `test/localsaathi_core_test.dart`). After the fixes in this session: **+74 ~1 −10**, with the same 10 failures. |
| [006](phase-006.md) Supabase parity | **Blocked** | No Docker / Supabase CLI. Owner: product owner installs Docker Desktop; integration engineer runs the scripted 4 HTTP checks. Private-object denial has no coverage anywhere yet. |
| [007](phase-007.md) Release config | Accepted | API 36, minSdk 24, INTERNET only. Fail-open: release falls back to debug signing without `key.properties`; `lib/main.dart:28,36` always wires `AppDependencies.mock`. |
| [008](phase-008.md) Research brief | Accepted | Outreach drafted, not sent. Hindi/Marathi consent copy needs native review. |
| [009](phase-009.md) Launch boundaries | Accepted after rework | 45 categories / 43 Mumbai localities verified by command. One contiguous pilot cluster; healthcare off until credential review exists. |
| [010](phase-010.md) Metrics | Accepted | Contact taps never counted as jobs; thresholds are proposals until pilot data. |
| [011](phase-011.md) Architecture | Accepted with correction | Admin tool relabelled planned; deletion leaves Storage objects and device keys behind. |
| [012](phase-012.md) Threat model | Accepted | Top risk verified by reviewer: public phone exposure (see below). |
| [013](phase-013.md) Data classification | Accepted | Allowlist projection specified; implementation is phase 022. |
| [014](phase-014.md) Contracts | Accepted | 7 fixtures in `docs/contracts/fixtures/` parse; 6 mismatches incl. enum casing (`not_started` vs `notStarted`). |
| [015](phase-015.md) ADRs | Accepted with correction | 24 h provider-page cache replaced with live / purge-on-revoke caching. |
| [016](phase-016.md) Cost worksheet | Accepted as template | All prices unverified placeholders; no accounts created. |
| [017](phase-017.md) Feature flags | Accepted | Server-enforced flags; cities reuse `cities.launch_status`. |
| [018](phase-018.md) Agent protocol | Accepted | This session is the handoff trial (9 parallel workers, disjoint files, reviewer re-ran verification). |
| [019](phase-019.md) Capacity | Accepted after reviewer correction | Core slice 601–1,202 h base (751–1,503 h with contingency; solo ≈25–50 weeks); WS13–15 required controls restored. |

## Reviewer-verified launch blockers (carry into phases 021+)
1. **Phone numbers are public regardless of consent.** `provider_profile_json` emits `phoneE164` (`backend/supabase/migrations/20260101000008_functions.sql:90`); anon has `SELECT` on raw published `provider_profiles` rows (`...0009_rls.sql:71,74`). → phases 022, 025, 032.
2. **Anon can EXECUTE every public function, including future ones** (`...0009_rls.sql:16-17`). → phases 023, 024.
3. **Release can ship mocks and debug signing** (`lib/main.dart:28,36`; `android/app/build.gradle:12-14`). → phases 061, 281+.
4. **Unbounded search/listing** (`search_providers` `p_limit` uncapped, `0008:323`). → phase 034.
5. **Contact actions not wired.** → phase 061–080.
6. **Deletion leaves Storage objects and device data** (`delete-account/index.ts:48` deletes only the auth user). → phase 035 and 049/051.
7. **No version control.** Recovery today = session-temporary tarball. → owner to `git init` + baseline commit before phase 021.

## Frozen core-release scope
- **In:** guest browsing, local bookmarks, en/hi/mr (full translation required), one contiguous Mumbai pilot cluster, ~28 non-healthcare categories via `is_approved_for_launch`, phone-verified providers (identity only, never "professional verification"), call/WhatsApp contact, reporting, deletion, website, signed Android build, backups/restore drill.
- **Off by server flag:** Saathi AI, healthcare listings, media/credential intake until server validation exists, sponsored placement, paid billing, additional cities.
- **Excluded:** emergency dispatch, booking guarantees, escrow, outcome claims.

## Open decisions (owner → next step)
| Decision | Owner | Next step |
|---|---|---|
| Install Docker to unblock phase 006 | Product owner | Install Docker Desktop, then run the script plan in phase-006.md |
| `git init` + baseline commit | Product owner | Approve; then commit current tree before phase 021 |
| Confirm pilot cluster and category list | Product owner + ops | Pick cluster from phase-009 options |
| Run the Idea Council 10-minute test (incumbent stale-number check) | Product owner | See `council/verdicts.md`; result decides whether to proceed past FIX FIRST |
| Staffing model (solo vs team) | Product owner | Choose from phase-019 options |
| SMS vendor + DLT registration | Product owner | Start early; 2–4 week lead time |
| Legal counsel (DPDP, healthcare, wireman licence) | Product owner | Engage before phase 241 |

## Commands run by reviewer
- `node backend/scripts/verify-db.mjs` → `Tests: 5/5 files passed, 17/17 assertions passed. PASS`
- `flutter test --no-pub -r compact` → `+58 -10: Some tests failed.`
- Category/locality counts, l10n override counts, and grant/exposure lines checked with grep (cited above).

## Not done in this gate (honest list)
- No full Supabase stack, no device run, no release build, no screenshots taken.
- No UI/motion work. Phases 001–020 have no UI scope. Motion/animation skills apply from Workstream 7/8 (phases 121–160).

## Rollback
Evidence-only phases, apart from phase 004. Phase 004 can be reverted from the baseline tarball in the session scratchpad (`baseline-2026-10-06.tgz`; temporary, so commit to git).

## Deep re-verification (2026-10-07)
The user challenged the first pass ("how do you finish so fast"). I ran a second round of checks:
- **Independent citation audits.** Two auditors re-checked phases 001–019; their corrections are tagged `[audit-corrected]`. Two of their own claims were wrong and I rejected them: the l10n count of 630 (it double-counted overrides; the real figure is 479) and "export script missing" (the file is `tool/export_web_data.py`).
- **Browser walkthrough at 375 px** (phase 002) found a **crash in Hindi and Marathi**: Material localizations were missing, so the navigation rendered as grey error boxes and logged 22 console errors. Fixed with `flutter_localizations` plus a regression test; 0 console errors afterwards.
- **Draft leak on shared phones** (phase 003) reproduced by actually running a test: `test/account_switch_draft_test.dart`, skipped until phases 049/051 fix it.
- **Phase 019 slice corrected:** the minimum launch is 601–1,202 h base, or 751–1,503 h with contingency.
