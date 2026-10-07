-- Shared test fixtures. Not wrapped in a transaction -- it creates a `tests`
-- schema and helper functions that the other numbered test files reuse, and
-- those files roll back their own fixture *data*, not this schema.
create schema if not exists tests;

-- A minimal confirmed-phone auth user, the way Supabase Auth leaves one after
-- a real OTP verification. If this insert fails on your local stack, your
-- auth.users schema has a NOT NULL column not listed here -- add it, the
-- test logic below does not depend on any column but these.
create or replace function tests.create_phone_user(p_phone text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    id, instance_id, aud, role, phone, phone_confirmed_at, created_at, updated_at
  ) values (
    v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    p_phone, now(), now(), now()
  );
  return v_id;
end;
$$;

-- Runs the rest of the current transaction as if `p_user_id` were the
-- authenticated caller -- the standard Supabase pattern for exercising RLS
-- from pgTAP (auth.uid() reads request.jwt.claims ->> 'sub').
create or replace function tests.authenticate_as(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user_id, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end;
$$;

-- Minimal reference rows every test needs: one active city/locality, one
-- coming-soon city/locality, one category. Idempotent so tests can run in
-- any order against a freshly seeded or unseeded database.
create or replace function tests.ensure_reference_data()
returns void
language plpgsql
as $$
begin
  insert into public.countries (id, name, iso_code, dial_code)
    values ('in', 'India', 'IN', '91') on conflict (id) do nothing;
  insert into public.state_regions (id, country_id, name)
    values ('in-mh', 'in', 'Maharashtra') on conflict (id) do nothing;
  insert into public.cities (id, state_id, name, launch_status) values
    ('test-active-city', 'in-mh', 'Test Active City', 'active'),
    ('test-coming-soon-city', 'in-mh', 'Test Coming Soon City', 'coming_soon')
  on conflict (id) do update set launch_status = excluded.launch_status;
  insert into public.localities (id, city_id, name) values
    ('test-locality-a', 'test-active-city', 'Locality A'),
    ('test-locality-b', 'test-active-city', 'Locality B'),
    ('test-locality-c-other-city', 'test-coming-soon-city', 'Locality C')
  on conflict (id) do nothing;
  insert into public.service_groups (id, name, icon_key)
    values ('test-group', 'Test group', 'other') on conflict (id) do nothing;
  insert into public.service_categories (id, group_id, name, icon_key) values
    ('test-category-plumbing', 'test-group', 'Test Plumbing', 'plumbing'),
    ('test-category-electrical', 'test-group', 'Test Electrical', 'electrical')
  on conflict (id) do nothing;
end;
$$;

-- Inserts a published, active, consented provider row directly (bypassing
-- register_profile, since that function requires a *real* jwt/session
-- context that varies by Supabase version). Returns the new profile id.
create or replace function tests.create_published_provider(
  p_user_id uuid, p_phone text, p_name text,
  p_city_id text default 'test-active-city',
  p_base_locality_id text default 'test-locality-a',
  p_extra_service_locality text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.provider_profiles (
    user_id, phone_e164, display_name, base_city_id, base_locality_id,
    phone_display_consented, status, moderation_status
  ) values (
    p_user_id, p_phone, p_name, p_city_id, p_base_locality_id,
    true, 'draft', 'active'
  ) returning id into v_id;

  insert into public.provider_categories (provider_id, category_id)
    values (v_id, 'test-category-plumbing');
  insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary)
    values (v_id, p_city_id, p_base_locality_id, true);
  if p_extra_service_locality is not null then
    insert into public.provider_service_areas (provider_id, city_id, locality_id)
      values (v_id, p_city_id, p_extra_service_locality);
  end if;

  update public.provider_profiles set status = 'published' where id = v_id;
  return v_id;
end;
$$;

-- Moderation fixtures must go through the real admin gate: the
-- enforce_profile_mutation_rules trigger only lets an admin (a row in
-- app_admins, matched via auth.uid()) change moderation_status or
-- suspension_reason. This registers a throwaway admin and applies the change
-- under that admin's claims, then restores the caller's claims. Nothing is
-- disabled or bypassed.
create or replace function tests.moderate_as_admin(
  p_provider_id uuid, p_moderation_status public.moderation_status, p_reason text default null
)
returns void
language plpgsql
as $$
declare
  v_admin uuid := (select id from auth.users where phone = '+919000000999');
  v_prev text := current_setting('request.jwt.claims', true);
begin
  if v_admin is null then
    v_admin := tests.create_phone_user('+919000000999');
    insert into public.app_admins (user_id) values (v_admin);
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  update public.provider_profiles
    set moderation_status = p_moderation_status, suspension_reason = p_reason
    where id = p_provider_id;
  perform set_config('request.jwt.claims', coalesce(v_prev, ''), true);
end;
$$;

-- Lets the switched API roles read/write a session-local fixture table (a
-- temp table is owned by the postgres session, so `authenticated` and `anon`
-- get "permission denied" on it otherwise). Test-only; temp tables vanish at
-- session end and carry no production data.
create or replace function tests.share_fixture(p_table regclass)
returns void
language plpgsql
as $$
begin
  execute format('grant all on %s to anon, authenticated', p_table);
end;
$$;

-- Suites call these after switching to anon/authenticated. Migration 0013
-- stopped new functions being executable by PUBLIC, so grant them -- the
-- tests schema never exists outside the test database.
grant usage on schema tests to anon, authenticated;
grant execute on all functions in schema tests to anon, authenticated;

-- Added for suites 0006-0013: a user who is also a row in app_admins. Call it
-- as the superuser, then authenticate_as(<returned id>) to act as the admin.
create or replace function tests.create_admin(p_phone text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := tests.create_phone_user(p_phone);
begin
  insert into public.app_admins (user_id) values (v_id);
  return v_id;
end;
$$;
grant execute on function tests.create_admin(text) to anon, authenticated;

-- Feature flags default to production values (most intake off); a suite that
-- exercises a gated capability turns its flag on inside its own transaction.
create or replace function tests.set_flag(p_key text, p_enabled boolean)
returns void
language sql
as $$
  insert into public.feature_flags (key, enabled, reason) values (p_key, p_enabled, 'test')
  on conflict (key) do update set enabled = excluded.enabled;
$$;
