# Phase 040 - independent red-team review (second reviewer)

Date: 2026-10-07. Scope: backend/supabase migrations 0001-0020 + seed.sql on PGlite + Supabase stub.
Probe scripts (scratchpad, not in repo): redteam040.mjs (main), redteam040b.mjs (storage, spam, DoS). Raw output: scratchpad/run1.txt.
The pgTAP suites were NOT read or reused.

## Method
- createDb() + migrate() + seed.sql. auth.users inserted in GoTrue phone format (no '+', confirmed); admin in app_admins.
- Actors: anon, C (signed in, no profile), A and B (providers), D (consent withdrawn), E (suspended), F (city flipped to coming_soon after publish), G (only category flipped to un-approved), ADM.
- Roles simulated like PostgREST: `set role anon|authenticated` + `set_config('request.jwt.claims', ...)` + `request.headers`.
- Case 1: `select *` on every table in every non-system schema as anon/C/B. Every non-trigger function in pg_proc with has_function_privilege(role) called with 3 arg strategies (ids of A, ids of B, all NULL); output scanned for markers: other users' phone digits, user_ids, exact pin 19.1234567/72.7654321, suspension reason, pending credential title/number.
- Cases 3-5: every owner/admin RPC against another account's profile; ~35 direct DML/TRUNCATE statements (public and private) as A and anon with row-count diffs.
- Case 6: added 1,500 published listings (1,504 total) and timed every input combination.

## Summary
HELD 6 of 6 mandatory cases (each has many sub-probes, all held), BROKEN 0. New findings: 1 medium (deployment-conditional), 2 low, 1 info.
Detector false positives, reviewed and not defects: consented providers' phone appears in get_public_profile/similar_providers (intended, phone_display_consented=true); B reading B's own consent_records; get_owner_profile(B) as A returns SQL NULL, identical to a random uuid (`[{"j":null}]` both), so no data and no existence oracle.

## Case 1 - disclosure: HELD
- anon selectable tables: only reference data (cities 62, countries, localities, service_categories, service_groups, state_regions, subscription_plans) plus storage.buckets/objects (0 rows). `private.*`: `permission denied for schema private`.
- C: provider_profiles(0), credential_records(0), consent_records(0), city_requests(0), promotions(0), app_admins(0).
- B sees exactly one provider_profiles row (own). No other user's marker appeared in any table.
- Function sweep: anon 84 executable functions, C 103 (11 discovery/guest RPCs, is_admin, owner RPCs, plus extension/auth/storage helpers). No function returned another user's user_id, exact lat/lng, suspension reason or credential state; only consented phones (intended).
- Public JSON keys: id, photos, status, pinCodes, createdAt, languages, phoneE164, updatedAt, baseCityId, homeVisits, categoryIds, description, displayName, mapLocation (rounded: `{"lat":19.12,"lng":72.77}`), availability, serviceAreas, verification (approved only), workingHours, baseLocalityId. No userId, no moderation/suspension fields.

## Case 2 - ineligible listings in discovery: HELD
States: D paused + consent false, E suspended ("SECRETREASON"), F coming_soon, G only un-approved category.
```
search_providers (anon and C)        -> ["Alpha Plumber","Bravo Plumber"]
providers_published_in_city mumbai   -> 2 ; thane -> [] ; search thane -> {"items":[],"totalCount":0}
get_public_profile D/E/F/G           -> null,null,null,null
provider_count_by_locality           -> {"mh-mumbai-andheri-west":2}
search category filter ['carpentry'] -> {"items":[],"totalCount":0}
active_promotions (promos inserted for D,E,G,A) -> ["A"] only; sponsored search path adds no ineligible row
similar_providers(withdrawn D)       -> []
```
Re-list attempts: D republish without consent -> `listing_not_publishable`; re-granting consent via update_profile_full leaves status paused; E republish -> `suspended: a suspended listing cannot be published`; A switching to only un-approved category while published -> get_public_profile is null immediately.

## Case 3 - cross-account writes: HELD
A -> B via update_profile_full, set_listing_status, set_availability, delete_listing, add_provider_photo (own and victim folder), record_consent, set_map_location, record_terms_acceptance, delete_provider_photo, engagement_summary_for: all `not_owner: ...`. anon: `permission denied for function ...` for each. 20+ direct DML statements on provider_profiles/photos/consent/categories/areas/hours/prices as A and anon: `permission denied for table ...`, counts unchanged. promotion_interest insert for B as A -> RLS violation. Storage: A cannot insert into B's folder, cannot see/update/delete B's objects, cannot read B's credential-evidence (0 rows).

## Case 4 - identity, moderation, credentials: HELD
- C registers with injected keys phoneE164, phone, userId, user_id, id, moderationStatus, status, suspensionReason, verification: stored row is `phone_e164=+919800000003 (own, from auth.users), status draft, moderation active, own user_id`.
- B update_profile_full with phone, phoneE164, moderationStatus, userId, status, suspensionReason: protected columns unchanged. Direct UPDATE: permission denied.
- Unconfirmed GoTrue phone change does not propagate to the profile.
- A cannot insert a credential row (no table grant for it in the sweep; RLS blocks B's), cannot call record_credential_review / set_listing_moderation / set_city_launch_status / admin_audit_events (`not_owner`). Forged JWT claim `is_admin:true` / app_metadata admin not honoured. Unverified-phone user, user without auth.users row, anon: `not_authenticated` / permission denied.

## Case 5 - guest writes, audit, private: HELD (limit bypass: see F1)
anon DML on reports/engagement_events/city_requests: permission denied. private.audit_events insert/update/delete/truncate, private.rate_limits, private.idempotency_keys, private.write_audit/take_rate_token/apply_consent as anon or A: `permission denied for schema private`. Audit rows exist only for admin actions, actor recorded. With honest headers: same source x40 reports -> 1 row; XFF first-hop rotation (last hop used) x20 -> 1 row; no source x80 -> 50 rows (provider cap); no-source engagement x700 -> 600; request_city same source x20 -> 5.

## Case 6 - resource abuse: HELD
1,504 published listings: limit 1e9/maxint -> 50 rows in 62 ms; limit -1 -> 1; null -> 20; offset 500 ok, 501/maxint -> `refine the search`; 21 categories rejected; 81-char text rejected; 80-char `%_`, multibyte, space-padded texts <= 65 ms; search_cities <= 50 rows (2 ms); search_categories 44 rows; similar_providers limit 1e9 -> 12; providers_published_in_city -> 500 (52 ms); admin_audit_events 1e9 -> capped. Slowest call 65 ms (limit 5 s).

## Creative attacks: HELD
SQL injection strings in search_providers/search_cities/search_categories/provider_count_by_locality are data (cities table intact, 62). search_path hijack (evil.btrim, evil.now, caller search_path=evil,public): no effect; no SECURITY DEFINER function in public/private lacks a pinned search_path. Idempotency key reused across two users: second user gets own new profile; same-user replay returns same id. Stale expectedRevision on 2nd update -> `conflict: revision_mismatch (you have 4, current is 5)`. NULL, NaN, 999, huge bigint, path traversal, trailing newline all rejected; map pin unchanged. Photo cap enforced (5 of 100 attempts).

## New findings
**F1 - MEDIUM (deployment-conditional): rate limits trust client-controllable headers.** private.request_source() prefers `cf-connecting-ip`, else the last `x-forwarded-for` hop. If the API is reachable without a proxy that overwrites them (self-hosted Kong, custom domain not behind Cloudflare), an anonymous caller rotating the header defeats every per-source limit.
Reproduction (role anon, `set_config('request.headers','{"cf-connecting-ip":"10.0.<i>.1"}')` per call):
- submit_report x80 on one listing -> 50 rows (per-source dedup bypassed; only the 50/day provider cap stops it).
- That cap is also a DoS: after the 60 rotated calls a legitimate report from a fresh IP returns `rate_limited: this listing has many open reports already`; reporters locked out for the day and the admin queue gets 50 junk rows.
- record_engagement rotating IP x300 -> 300 rows (10/h per source+provider+type bypassed; no per-provider ceiling on the sourced path): engagement and sponsor metrics inflatable without bound.
- request_city rotating IP x20 -> 25 total rows (cap 5 per source bypassed), unbounded.
On hosted Supabase behind Cloudflare the edge sets the header, so exposure is low; confirm the production topology and document it. Mitigation: per-listing/global ceilings on the engagement and city_request paths; do not let the per-provider report cap lock out all reporters (reserve slots or count distinct sources).

**F2 - LOW: authenticated append RPCs are not rate-limited.** 300 x record_consent(marketing_contact) -> 303 consent_records rows; 300 x record_terms_acceptance -> 603 rows. One verified account can grow the retained evidence table without bound. Add a per-owner token (private.take_rate_token) or skip no-change decisions.

**F3 - LOW/INFO: optimistic revision does not cover child rows.** add_provider_photo leaves revision unchanged (6 -> 6) though it changes the public profile, so photo edits and field edits from two devices never conflict. Field/category edits do bump it (5 -> 6).

**F4 - INFO: extension helpers executable by API roles.** pgcrypto/pg_trgm functions in schema `extensions` (crypt, hmac, gen_salt, pgp_*, similarity...) and auth.* helpers are EXECUTE-able by anon (84 functions total). Not reachable over PostgREST because config.toml exposes only `public, graphql_public`; becomes live if `extensions` is ever exposed. Consider revoking from anon/authenticated.

Not a defect: storage insert policy accepts `<uid>/../<other>/z.jpg` (first folder segment is the caller), but add_provider_photo's regex rejects it, so it cannot be attached to a listing.
