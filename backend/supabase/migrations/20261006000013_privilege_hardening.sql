-- Phases 023/024: replace "everything is callable/writable by everyone, RLS
-- sorts it out" with explicit allowlists.
--
-- Before this migration (see tasks/evidence/phase-021.md):
--   * 0009 granted EXECUTE on every public function, and default privileges
--     granted EXECUTE on every *future* one, to anon and authenticated; and
--     Postgres itself grants EXECUTE to PUBLIC on every new function.
--   * Supabase's default privileges grant ALL on every public table to anon
--     and authenticated, so RLS policies were the only barrier, including
--     for INSERT/UPDATE/DELETE that no client should ever send directly.
--   * pg_trgm was installed into `public`, exposing ~30 C functions over RPC.
--
-- After it: functions and tables are closed by default; each later migration
-- grants exactly what its client contract needs. Trigger functions need no
-- EXECUTE grant (Postgres does not check it when a trigger fires). Helpers
-- called inside SECURITY DEFINER functions run as the definer, so they stay
-- usable without being exposed.

-- 1. Extensions out of the exposed schema. Index opclasses move with it.
alter extension pg_trgm set schema extensions;

-- 2. Functions: nobody may execute anything in public unless granted below
-- (or by a later migration).
revoke execute on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges revoke execute on functions from public;
grant execute on all functions in schema public to service_role;

-- Customer discovery: guests and signed-in users alike.
grant execute on function
  public.search_providers(text, text, text, text[], text[], boolean, boolean, int, int),
  public.get_public_profile(uuid),
  public.similar_providers(uuid, int),
  public.provider_count_by_locality(text),
  public.providers_published_in_city(text),
  public.active_promotions(text, text, text, public.promotion_placement),
  public.search_cities(text, text),
  public.search_categories(text)
to anon, authenticated;

-- RLS policies call is_admin() while evaluating any role's query, so every
-- API role must be able to execute it. It only ever answers about the caller.
grant execute on function public.is_admin() to anon, authenticated;

-- Signed-in providers (each function checks ownership or admin itself).
grant execute on function
  public.get_owner_profile(uuid),
  public.my_profile(),
  public.my_account(),
  public.register_profile(jsonb),
  public.update_profile_full(uuid, jsonb),
  public.set_map_location(uuid, double precision, double precision),
  public.record_terms_acceptance(uuid, text),
  public.engagement_summary_for(uuid),
  public.record_credential_review(uuid, uuid, public.verification_status, text),
  public.set_listing_moderation(uuid, public.moderation_status, text)
to authenticated;

-- Deliberately NOT granted: provider_profile_json(_core) (owner-shaped JSON
-- for any id), assert_locality_in_city, and every trigger function.

-- 3. Definer functions: empty search_path, so nothing a caller can influence
-- (session search_path, objects in writable schemas) changes name resolution.
-- Every body already schema-qualifies its tables; built-ins live in pg_catalog,
-- which is always searched.
alter function public.is_admin() set search_path = '';
alter function public.handle_auth_phone_change() set search_path = '';
alter function public.get_public_profile(uuid) set search_path = '';
alter function public.get_owner_profile(uuid) set search_path = '';
alter function public.search_providers(text, text, text, text[], text[], boolean, boolean, int, int) set search_path = '';
alter function public.similar_providers(uuid, int) set search_path = '';
alter function public.provider_count_by_locality(text) set search_path = '';
alter function public.register_profile(jsonb) set search_path = '';
alter function public.record_credential_review(uuid, uuid, public.verification_status, text) set search_path = '';
alter function public.set_listing_moderation(uuid, public.moderation_status, text) set search_path = '';
alter function public.engagement_summary_for(uuid) set search_path = '';
alter function public.active_promotions(text, text, text, public.promotion_placement) set search_path = '';
alter function public.my_profile() set search_path = '';
alter function public.my_account() set search_path = '';
alter function public.providers_published_in_city(text) set search_path = '';
alter function public.update_profile_full(uuid, jsonb) set search_path = '';
alter function public.search_cities(text, text) set search_path = '';
alter function public.search_categories(text) set search_path = '';
alter function public.set_map_location(uuid, double precision, double precision) set search_path = '';
alter function public.record_terms_acceptance(uuid, text) set search_path = '';
-- Invoker helpers called from definer bodies: pin them too.
alter function public.provider_profile_json(uuid) set search_path = '';
alter function public.provider_profile_json_core(uuid) set search_path = '';

-- 4. Tables: close everything, then grant per table what a client may do
-- directly. Writes to provider data go through definer RPCs (0018); guest
-- submissions through rate-limited RPCs (0019).
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
grant all on all tables in schema public to service_role;

grant select on public.countries, public.state_regions, public.cities, public.localities,
  public.service_groups, public.service_categories, public.subscription_plans
to anon, authenticated;

-- Owner reads of their own rows (RLS "owner ..." policies); admins via
-- is_admin() branches. No anon access to any provider table.
grant select on public.provider_profiles, public.provider_categories, public.provider_service_areas,
  public.provider_working_hours, public.provider_photos, public.provider_starting_prices,
  public.provider_healthcare_details, public.consent_records, public.verification_records,
  public.credential_records
to authenticated;

-- Credential claims (forced to 'pending' by trigger; intake is feature-flagged).
grant insert (provider_id, title, issuing_body, registration_number, valid_until, evidence_storage_path),
  delete on public.credential_records to authenticated;

-- Admin-only surfaces, gated by is_admin() policies.
grant select, update on public.reports to authenticated;
grant select on public.engagement_events, public.city_requests, public.app_admins to authenticated;
grant select, insert, update, delete on public.promotions to authenticated;

-- A provider's own interest in a future plan (grants nothing by itself).
grant select, insert, update, delete on public.promotion_interest to authenticated;

-- 5. A schema for internal tables (audit, rate limits, idempotency). Not in
-- config.toml's exposed schemas, and no API role may even look inside.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;
