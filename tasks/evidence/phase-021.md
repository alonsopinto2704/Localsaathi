# Phase 021 — Database object and privilege inventory

**Status:** In review. Verified locally (PGlite); HTTP repetition Blocked (phases 006/039). · **Author/reviewer:** Opus chief engineer, 2026-10-06 · **Second human reviewer:** pending (phase 040)

## Objective
Enumerate every table, function, grant, default privilege and policy. Give every callable object a documented purpose, caller set and boundary, and exercise all four roles.

## Changed paths
- `backend/scripts/db-inventory.mjs` (new): prints the inventory straight from the catalog.
- `backend/scripts/db.mjs` (new): shared PGlite boot; `backend/scripts/verify-db.mjs` now uses it.

## Before (migrations 0001–0012), from `node backend/scripts/db-inventory.mjs`
- **Functions:** 61 in `public`, and **all 61 executable by PUBLIC, anon and authenticated**. That included:
  - 30 `pg_trgm` internals (the extension was installed in `public`);
  - `provider_profile_json`, which returns owner-shaped JSON for any id;
  - `assert_locality_in_city`.
- **Tables:** 23 in `public`, **every one granted SELECT/INSERT/UPDATE/DELETE to anon and authenticated** (Supabase default privileges). RLS was the only barrier, and no policy restricted roles.
- **Default privileges:** EXECUTE on future functions and ALL on future tables, for anon and authenticated.
- **Schema `public`:** anon and authenticated had no CREATE (the PG15+ default).

## After (0001–0019)
- **Functions:** anon can EXECUTE exactly **12**: 8 discovery RPCs, `submit_report`, `record_engagement`, `request_city`, and `is_admin` (RLS policies call it). `0006_privileges` asserts this exact set.
- **Definer functions:** every SECURITY DEFINER function in `public` and `private` has `search_path=""`.
- **Tables:** anon has **no** grant on any provider, consent, verification, report, engagement or admin table, and only SELECT on the 7 reference tables.
- **Internal state:** `audit_events`, `rate_limits`, `idempotency_keys` and `storage_cleanup_queue` live in the unexposed `private` schema, with no API-role usage.

## Callable surface and boundary
| Caller | Functions | Boundary |
|---|---|---|
| anon + authenticated | `search_providers`, `get_public_profile`, `similar_providers`, `provider_count_by_locality`, `providers_published_in_city`, `active_promotions`, `search_cities`, `search_categories` | `is_publicly_listed()` + the allowlisted `public_profile_json()` |
| anon + authenticated | `submit_report`, `record_engagement`, `request_city` | Listed-target check, bounds, rate limits (phase 033) |
| authenticated (owner) | `register_profile`, `update_profile_full`, `set_listing_status`, `set_availability`, `delete_listing`, `add_provider_photo`, `delete_provider_photo`, `record_consent`, `set_map_location`, `record_terms_acceptance`, `get_owner_profile`, `my_profile`, `my_account`, `engagement_summary_for` | `private.lock_owned_profile` (owner only), or scoping by `auth.uid()` |
| authenticated (admin, i.e. an `app_admins` row) | `set_listing_moderation`, `record_credential_review`, `set_city_launch_status`, `set_category_launch_approval`, `admin_audit_events` | `is_admin()` + an audit row in the same transaction |
| service_role only | `mark_storage_cleaned`, `private.purge_expired_records` | Not executable by client roles |
| Nobody (internal) | `provider_profile_json(_core)`, `public_profile_json`, `is_publicly_listed`, `private.*` helpers, all trigger functions | Called only inside definer functions |

Roles exercised: anon, owner, another owner and admin, across suites `0006`–`0013`. `node backend/scripts/verify-db.mjs` → `Tests: 14/14 files passed, 151/151 assertions passed. PASS`.

## Not verified here
Repeating these boundaries through real PostgREST and Storage HTTP (`backend/scripts/http-authz-pack.mjs`, phase 039). It is ready but cannot run without a Supabase project.

## Full post-hardening inventory (generated)
(Regenerated 2026-10-07 after migration 20261006000020.)

## Functions (58)

| schema.function(args) | definer | search_path | PUBLIC | anon | authenticated | trigger |
|---|---|---|---|---|---|---|
| `private.apply_consent(p_profile_id uuid, p_kind consent_kind, p_granted boolean, p_wording_version text)` | Y | "" | · | · | · | · |
| `private.audit_admin_change()` | Y | "" | · | · | · | Y |
| `private.hours_open(t_open integer, t_close integer, y_open integer, y_close integer, m integer)` | · | "" | · | · | · | · |
| `private.like_contains(p_text text)` | · | "" | · | · | · | · |
| `private.lock_owned_profile(p_profile_id uuid, p_expected_revision bigint)` | Y | "" | · | · | · | · |
| `private.normalize_e164(p_raw text)` | · | "" | · | · | · | · |
| `private.on_provider_profile_deleted()` | Y | "" | · | · | · | Y |
| `private.purge_expired_records()` | Y | "" | · | · | · | · |
| `private.reject_audit_mutation()` | · | "" | · | · | · | Y |
| `private.request_source()` | · | "" | · | · | · | · |
| `private.take_rate_token(p_bucket text, p_subject text, p_window interval, p_max integer)` | Y | "" | · | · | · | · |
| `private.validate_profile_payload(p jsonb, p_city_id text)` | · | "" | · | · | · | · |
| `private.write_audit(p_action text, p_target_type text, p_target_id text, p_reason text, p_details jsonb)` | Y | "" | · | · | · | · |
| `public.active_promotions(p_city_id text, p_locality_id text, p_category_id text, p_placement promotion_placement)` | Y | "" | · | Y | Y | · |
| `public.add_provider_photo(p_profile_id uuid, p_storage_path text, p_caption text)` | Y | "" | · | · | Y | · |
| `public.admin_audit_events(p_limit integer, p_before_id bigint)` | Y | "" | · | · | Y | · |
| `public.assert_locality_in_city(p_city_id text, p_locality_id text)` | · | — | · | · | · | · |
| `public.check_photo_limit()` | · | — | · | · | · | Y |
| `public.check_provider_has_category()` | · | — | · | · | · | Y |
| `public.check_provider_has_service_area()` | · | — | · | · | · | Y |
| `public.check_provider_profile_locality()` | · | — | · | · | · | Y |
| `public.check_service_area_locality()` | · | — | · | · | · | Y |
| `public.delete_listing(p_profile_id uuid)` | Y | "" | · | · | Y | · |
| `public.delete_provider_photo(p_photo_id uuid)` | Y | "" | · | · | Y | · |
| `public.enforce_profile_mutation_rules()` | Y | "" | · | · | · | Y |
| `public.engagement_summary_for(p_provider_id uuid)` | Y | "" | · | · | Y | · |
| `public.force_pending_credential_status()` | · | — | · | · | · | Y |
| `public.get_owner_profile(p_id uuid)` | Y | "" | · | · | Y | · |
| `public.get_public_profile(p_id uuid)` | Y | "" | · | Y | Y | · |
| `public.handle_auth_phone_change()` | Y | "" | · | · | · | Y |
| `public.is_admin()` | Y | "" | · | Y | Y | · |
| `public.is_publicly_listed(p_id uuid)` | Y | "" | · | · | · | · |
| `public.mark_storage_cleaned(p_user_id uuid)` | Y | "" | · | · | · | · |
| `public.my_account()` | Y | "" | · | · | Y | · |
| `public.my_profile()` | Y | "" | · | · | Y | · |
| `public.provider_count_by_locality(p_city_id text)` | Y | "" | · | Y | Y | · |
| `public.provider_profile_json(p_id uuid)` | · | "" | · | · | · | · |
| `public.provider_profile_json_core(p_id uuid)` | · | "" | · | · | · | · |
| `public.providers_published_in_city(p_city_id text)` | Y | "" | · | Y | Y | · |
| `public.public_profile_json(p_id uuid)` | · | "" | · | · | · | · |
| `public.record_consent(p_profile_id uuid, p_kind consent_kind, p_granted boolean, p_wording_version text)` | Y | "" | · | · | Y | · |
| `public.record_credential_review(p_provider_id uuid, p_credential_id uuid, p_status verification_status, p_note text)` | Y | "" | · | · | Y | · |
| `public.record_engagement(p_provider_id uuid, p_type engagement_event_type, p_city_id text, p_locality_id text, p_category_id text)` | Y | "" | · | Y | Y | · |
| `public.record_terms_acceptance(p_profile_id uuid, p_version text)` | Y | "" | · | · | Y | · |
| `public.register_profile(p_submission jsonb)` | Y | "" | · | · | Y | · |
| `public.request_city(p_city_name text, p_state_name text, p_note text)` | Y | "" | · | Y | Y | · |
| `public.search_categories(p_text text)` | Y | "" | · | Y | Y | · |
| `public.search_cities(p_text text, p_country_id text)` | Y | "" | · | Y | Y | · |
| `public.search_providers(p_city_id text, p_locality_id text, p_text text, p_category_ids text[], p_locality_filter_ids text[], p_open_now_only boolean, p_home_visits_only boolean, p_limit integer, p_offset integer)` | Y | "" | · | Y | Y | · |
| `public.set_availability(p_profile_id uuid, p_availability availability_status)` | Y | "" | · | · | Y | · |
| `public.set_category_launch_approval(p_category_id text, p_approved boolean, p_reason text)` | Y | "" | · | · | Y | · |
| `public.set_city_launch_status(p_city_id text, p_status city_launch_status, p_reason text)` | Y | "" | · | · | Y | · |
| `public.set_listing_moderation(p_provider_id uuid, p_status moderation_status, p_reason text)` | Y | "" | · | · | Y | · |
| `public.set_listing_status(p_profile_id uuid, p_status listing_status, p_expected_revision bigint)` | Y | "" | · | · | Y | · |
| `public.set_map_location(p_profile_id uuid, p_lat double precision, p_lng double precision)` | Y | "" | · | · | Y | · |
| `public.similar_providers(p_provider_id uuid, p_limit integer)` | Y | "" | · | Y | Y | · |
| `public.submit_report(p_provider_id uuid, p_reason report_reason, p_details text, p_reporter_phone text)` | Y | "" | · | Y | Y | · |
| `public.update_profile_full(p_profile_id uuid, p_patch jsonb)` | Y | "" | · | · | Y | · |

## Tables (29)

| table | RLS | anon | authenticated | policies (cmd: roles) |
|---|---|---|---|---|
| `private.audit_events` | · | · | · | — |
| `private.idempotency_keys` | · | · | · | — |
| `private.rate_limits` | · | · | · | — |
| `private.storage_cleanup_queue` | · | · | · | — |
| `public.app_admins` | Y | · | S | SELECT:public |
| `public.cities` | Y | S | S | ALL:public; SELECT:public |
| `public.city_requests` | Y | · | S | SELECT:public |
| `public.consent_records` | Y | · | S | SELECT:public |
| `public.countries` | Y | S | S | ALL:public; SELECT:public |
| `public.credential_records` | Y | · | SD | DELETE:public; INSERT:public; SELECT:public |
| `public.engagement_events` | Y | · | S | SELECT:public |
| `public.localities` | Y | S | S | ALL:public; SELECT:public |
| `public.promotion_interest` | Y | · | SIUD | ALL:public |
| `public.promotions` | Y | · | SIUD | ALL:public |
| `public.provider_categories` | Y | · | S | ALL:public |
| `public.provider_healthcare_details` | Y | · | S | ALL:public |
| `public.provider_photos` | Y | · | S | ALL:public |
| `public.provider_profiles` | Y | · | S | SELECT:public |
| `public.provider_service_areas` | Y | · | S | ALL:public |
| `public.provider_starting_prices` | Y | · | S | ALL:public |
| `public.provider_working_hours` | Y | · | S | ALL:public |
| `public.reports` | Y | · | SU | SELECT:public; UPDATE:public |
| `public.service_categories` | Y | S | S | ALL:public; SELECT:public |
| `public.service_groups` | Y | S | S | ALL:public; SELECT:public |
| `public.state_regions` | Y | S | S | ALL:public; SELECT:public |
| `public.subscription_plans` | Y | S | S | ALL:public; SELECT:public |
| `public.verification_records` | Y | · | S | SELECT:public |
| `storage.buckets` | Y | SIUD | SIUD | — |
| `storage.objects` | Y | SIUD | SIUD | DELETE:public; DELETE:public; INSERT:public; INSERT:public; SELECT:public; UPDATE:public |

## Default privileges

| owner | schema | object type (r=table f=function S=sequence) | ACL |
|---|---|---|---|
| postgres | (all) | f | `{postgres=X/postgres}` |
| postgres | public | S | `{service_role=rwU/postgres}` |
| postgres | public | f | `{service_role=X/postgres}` |
| postgres | public | r | `{service_role=arwdDxtm/postgres}` |

## CREATE on schema public

- anon: no
- authenticated: no
