# Audit follow-up — phases 001–040 (2026-10-07)

**Status:** Done locally; human sign-off pending. · **Reviewer:** Opus chief engineer · **Inputs:** two external audits pasted by the product owner (phases 001–020 re-audit; phases 021–040 audit), council review (`council/verdicts.md`).

Every claim was checked against the repo before acting. Outcome: **fixed**, **deferred** (with owner phase), or **rejected** (the claim was wrong).

## Verification (all re-run after the last change)
| Check | Result |
|---|---|
| `node backend/scripts/verify-db.mjs` | 22/22 migrations, 166/166 columns classified, **16/16 files, 172/172 assertions PASS** |
| `node backend/scripts/rehearse-migrations.mjs` | **19/19** checks (2,000 synthetic providers, upgrade from 0001–0012) |
| `node backend/scripts/http-authz-pack.mjs --self-test` | PASS (live run still blocked: phase 006/039) |
| `flutter test --no-pub` | **+96 ~2 −0** — first fully green run; the 2 skips are decoder defects #1/#4 (phase 014) |
| `flutter analyze` | 0 errors, 0 warnings (infos only, mostly pre-existing) |

## Fixed
| Audit item | Fix | Proof |
|---|---|---|
| 021–040 P0#1: `public_profile_json` leaked the owner's auth id via `photos[].storagePath` | Photos keyed by **profile id** (`provider-photos/<profile_id>/…`); new storage policies; legacy `<user_id>/` paths withheld from public JSON; delete-account cleans both folders | `0015_audit_followups` #1–2 (value scan of the whole JSON); `0016_storage_policies`; HTTP pack now value-scans for `OWNER_USER_ID` |
| P0#2: published listing could be edited to zero launch-approved categories | `update_profile_full` asserts the listing stays publishable (category + service area) after the edit | `0015` "cannot drop to only unapproved categories" |
| P0#3: cleanup prefix race / orphaned photo files | Exact object paths queued on photo and credential row delete; listing folder (unique per profile) queued on listing delete; never the user's whole folder | `0015` exact-path test; `0013` updated |
| P0#4: credential evidence could point at another user's file | Insert trigger: path must be `<owner uid>/…`, field lengths, 10/day, `credential_intake` flag | `0015` foreign-folder test |
| P0#5: audit redaction missed `+91 98765 43210`; false-positive on timestamps | Strips UUIDs and ISO timestamps, joins formatted digits, matches E.164 or Indian-mobile shapes (epoch values pass) | `0015` two redaction tests; `0014` still green |
| P0#6: admin writes to `reports`/`promotions` unaudited | `after` triggers write `private.audit_events` for authenticated callers | trigger in `20261007000022` |
| P1#7: raw 22023/23502/23503 from owner RPCs | Shape validation (object/array/element types, 6-digit pin codes, price category ∈ chosen categories, healthcare field length) + error mapping in both RPCs | `0015` scalar `serviceAreas`, bad pin code |
| P1#8: revision bumped up to 3× per call; `'v1'` vs `'consent-v1'` | One bump per RPC call (`trg_zz_cap_revision`); table default `consent-v1`; `set_map_location` writes `consent-v1` and is rate-limited | `0015` "bumps revision exactly once" |
| P1#9: report lockout by anon flood; unbounded sourced engagement; midnight hash rotation | Per-listing report budget split anon/auth; engagement per-listing ceiling for every caller; de-dupe also checks yesterday's hash | `0011`, `0014` green; HTTP pack header-rotation probe added |
| P2#11: unpinned `search_path` on invoker helpers | Every non-extension function in `public`/`private` pinned to `''` | `0006` green |
| P2#12: stale contract docs, error codes, plan status | `backend-contract.md` (owner-only RPCs, flags, photo paths, prefixes, migration range), `error-codes.json` (`RATE_LIMITED` list, new `FEATURE_DISABLED`), plan: 040 In review | — |
| 001–020: feature flags designed (017) but never built | `public.feature_flags`, `flag_enabled`, `get_client_flags`, audited `set_feature_flag`; enforced for media, credentials, precise location, signup, sponsored placement, contact reveal | `0015` flag tests; `0006` allowlist updated |
| 009/020: 14-category pilot never applied to data | `category_seed.dart` marks 31 categories (24 wave-2 + 7 healthcare) not approved; `seed.sql` regenerated; mock app lists only approved categories and hides listings without one (mirrors `is_publicly_listed`) | core taxonomy test asserts the exact 14 |
| 003: draft (with phone number) leaked across sign-out **and delete** | `SessionController` clears the draft on both | `account_switch_draft_test.dart` (2 tests, unskipped) |
| 005: 10 failing core tests | All root-caused (`phase-005.md` lists each) and fixed: 9-digit seed phones, account phone not moved on number change, ownership by stale session object, no phone verification record, sponsorship ignored text search, 4 tests with outdated assumptions | full suite green |
| 002: "verified plumbers", "Verified & active" trust copy | App: "Phone-verified & active", subhead says numbers are phone-confirmed; the HTML showcase and its generator were later deleted entirely (owner request) | `customer_journey_gaps_test` scans all l10n literals for unqualified "verified" |
| 001/010/011/014/015/016/037 stale text | Counts, paths, old phase numbers, `event_log.ts`, flows annotated post-WS2, rehearsal count | — |
| 021 inventory missed views | `db-inventory.mjs` includes views | `private.listed_providers (view)` now listed |
| 035: `mark_storage_cleaned` error ignored | Logged; signature takes the profile id | — |

## Deferred (not done; owner)
- `search_providers`/`similar_providers` still call `is_publicly_listed()` per row (P1#10). Measured p95 404 ms at 50k (phase 038) is inside budget; rewrite with `private.listed_providers` in Workstream 6 (101–120).
- Revoke `EXECUTE` on `extensions` functions from API roles (F4): needs the pgTAP grant moved test-side; Phase 264 (DB CI).
- Phone change (`handle_auth_phone_change`) writes no consent row for the new number; `consent_records.phone_e164` / `reports.reporter_phone_e164` lack the E.164 CHECK; `p_expected_revision` on photo/delete RPCs → Phases 049–052.
- `active_promotions` city/category strictness beyond the flag → Phase 109 (sponsored placement), which stays off.
- Provider wizard / pause / edit widget walkthrough (003); Marathi and 2× text on Search and Profile screens (002) → Workstream 7 (121–140).
- `phase-013` classification labels for fields the projection deliberately exposes (`created_at`, `updated_at`, `phone_display_consented`, `is_placeholder`): the projection is the allowlist and `0007` pins its keys; a label-vs-projection cross-check is Phase 264.
- Android release build still never run after the Gradle/AGP upgrade (RAM limit) → Phase 281.
- Incumbent desk test (Idea Council `FIX FIRST`) still not run → product owner, before Workstream 3 spend.

## Rejected (audit claims that were wrong)
- `"pglite-socket": "^0.0.20"` in `backend/package.json` — no such dependency exists.
- Files `20261006000018_engagement_and_requests.sql`, `20261006000016_public_private_projections.sql`, `20261006000020_admin_audit_and_moderation.sql`, `admin_audit_log` — none exist (actual: `…018_guest_writes`, `…016_public_projection`, `…020_measured_indexes`, `private.audit_events`).
- "`_enumOr` in `provider.dart`" — it is in `moderation.dart`.
- "phase-020 marks Workstream 1 GO / all gates closed" — phase-020 already lists the incumbent test as **still open** and records the git deviation.

## Errors I (Claude) made earlier, now corrected
- `phase-005.md` said `createProfile` never updates `_store.session`. Wrong: it does; the failing tests held a stale session object.
- Phase-009's 14-category pilot was written into evidence but never applied to the seed, so phase-020's frozen scope was not true in data.
- The phase 001–020 follow-up claimed old phase numbers were replaced in 015/016; three instances remained.
