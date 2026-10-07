-- Provider identity and listings.
--
-- Identity design: a provider's phone identity IS their Supabase Auth user
-- (auth.users, phone sign-in). That gives us, for free, from infrastructure
-- that is already battle-tested rather than hand-rolled:
--   * normalised, verified phone numbers (Supabase Auth stores E.164 and only
--     sets phone_confirmed_at after a correct OTP);
--   * "one verified phone number = one account" (auth.users.phone is unique
--     for confirmed users).
--
-- "= one public profile" is then a single UNIQUE constraint:
-- provider_profiles.user_id references auth.users(id) UNIQUE. A second
-- registration attempt for the same signed-in user is rejected by Postgres
-- itself, not by application code -- see register_profile() in
-- 0008_functions.sql, which re-checks this at the point of write and turns
-- the unique_violation into a clean error, exactly mirroring what
-- MockProviderAuthRepository.registerProfile does today.
--
-- provider_profiles.phone_e164 is a denormalised copy of auth.users.phone,
-- kept in sync by the trigger in 0007_auth_sync.sql. It exists so every other
-- table and every search query can filter/display the phone without joining
-- into the auth schema (which RLS on the public schema cannot see).

create type public.listing_status as enum ('draft', 'published', 'paused');

-- Deliberately separate from listing_status (requirement: "a provider cannot
-- reactivate a suspended listing simply by changing its status"). Only an
-- admin may change this column -- enforced in enforce_profile_mutation_rules()
-- below and in 0009_rls.sql, not just by hiding a control in the UI.
create type public.moderation_status as enum ('active', 'suspended');

create type public.availability_status as enum ('available', 'busy', 'unavailable');

create table public.provider_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  phone_e164 text not null unique,
  display_name text not null,
  base_city_id text not null references public.cities(id),
  base_locality_id text not null references public.localities(id),
  description text,
  languages text[] not null default '{}',
  home_visits boolean not null default true,
  availability public.availability_status not null default 'available',
  whatsapp_enabled boolean not null default false,
  -- Mandatory before publish. Without this the UI must never render a Call
  -- button, and the backend must never publish the listing either.
  phone_display_consented boolean not null default false,
  status public.listing_status not null default 'draft',
  moderation_status public.moderation_status not null default 'active',
  suspension_reason text,
  pin_codes text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz
);

create table public.provider_categories (
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  category_id text not null references public.service_categories(id),
  primary key (provider_id, category_id)
);

create table public.provider_service_areas (
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  city_id text not null references public.cities(id),
  locality_id text not null references public.localities(id),
  is_primary boolean not null default false,
  pin_codes text[] not null default '{}',
  primary key (provider_id, locality_id)
);

-- Zero rows for a provider means "hours not provided" -- the client's
-- WorkingHours.hasAnyHours == false sentinel. A provider that *has* set hours
-- always has all 7 rows (weekday 1..7); a day with no hours still gets a row
-- with open/close minutes = null, which is how `isOpenAt` tells "closed today"
-- apart from "no hours exist at all".
create table public.provider_working_hours (
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  open_minutes smallint check (open_minutes between 0 and 1439),
  close_minutes smallint check (close_minutes between 0 and 1439),
  primary key (provider_id, weekday)
);

create table public.provider_photos (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  caption text not null default '',
  -- Path inside the `provider-photos` Storage bucket (see backend/README.md).
  -- remote_url is populated by the client/server when serving a public URL;
  -- storage_path is the source of truth for ownership checks.
  storage_path text,
  remote_url text,
  is_placeholder boolean not null default false,
  uploaded_at timestamptz not null default now()
);

create table public.provider_starting_prices (
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  category_id text not null references public.service_categories(id),
  amount_rupees int not null check (amount_rupees >= 0),
  note text,
  primary key (provider_id, category_id)
);

-- Healthcare-specific fields. All provider-claimed, never backend-generated
-- or verified by this table -- see credential_records in
-- 0005_trust_moderation.sql for the actual verification trail.
create table public.provider_healthcare_details (
  provider_id uuid primary key references public.provider_profiles(id) on delete cascade,
  qualification text,
  specialty text,
  clinic_name text,
  clinic_address text,
  consultation_hours_note text,
  registration_number text,
  registration_council text,
  is_diagnostic_centre boolean not null default false,
  accepts_walk_ins boolean not null default true
);

-- ---------------------------------------------------------------------------
-- Cross-table invariants that a single FK cannot express.

-- A locality must actually belong to the city it is claimed to be in. Reused
-- by provider_profiles (base city/locality) and provider_service_areas.
create or replace function public.assert_locality_in_city(p_city_id text, p_locality_id text)
returns void
language plpgsql
as $$
begin
  if not exists (
    select 1 from public.localities l where l.id = p_locality_id and l.city_id = p_city_id
  ) then
    raise exception 'validation_failed: locality % is not in city %', p_locality_id, p_city_id;
  end if;
end;
$$;

create or replace function public.check_provider_profile_locality()
returns trigger
language plpgsql
as $$
begin
  perform public.assert_locality_in_city(new.base_city_id, new.base_locality_id);
  return new;
end;
$$;

create trigger trg_provider_profile_locality
  before insert or update of base_city_id, base_locality_id on public.provider_profiles
  for each row execute function public.check_provider_profile_locality();

create or replace function public.check_service_area_locality()
returns trigger
language plpgsql
as $$
begin
  perform public.assert_locality_in_city(new.city_id, new.locality_id);
  return new;
end;
$$;

create trigger trg_service_area_locality
  before insert or update on public.provider_service_areas
  for each row execute function public.check_service_area_locality();

-- A provider must always keep at least one category and at least one service
-- area (mirrors MockProviderRepository.updateProfile's check, which runs on
-- every save, not only at publish time). Deferred so that a single
-- transaction replacing the whole set (delete-then-insert) does not trip on
-- its own intermediate empty state.
create or replace function public.check_provider_has_category()
returns trigger
language plpgsql
as $$
begin
  if not exists (select 1 from public.provider_profiles where id = old.provider_id) then
    return null; -- the profile itself is being deleted in this transaction
  end if;
  if not exists (select 1 from public.provider_categories where provider_id = old.provider_id) then
    raise exception 'validation_failed: a provider must keep at least one category';
  end if;
  return null;
end;
$$;

create constraint trigger trg_provider_has_category
  after delete on public.provider_categories
  deferrable initially deferred
  for each row execute function public.check_provider_has_category();

create or replace function public.check_provider_has_service_area()
returns trigger
language plpgsql
as $$
begin
  if not exists (select 1 from public.provider_profiles where id = old.provider_id) then
    return null;
  end if;
  if not exists (select 1 from public.provider_service_areas where provider_id = old.provider_id) then
    raise exception 'validation_failed: a provider must keep at least one service area';
  end if;
  return null;
end;
$$;

create constraint trigger trg_provider_has_service_area
  after delete on public.provider_service_areas
  deferrable initially deferred
  for each row execute function public.check_provider_has_service_area();

-- Free listings are capped at AppConfig.freePhotoLimit (5) photos. Keep this
-- constant in sync with lib/core/config/app_config.dart by hand -- there is no
-- subscription/entitlement table yet (monetization checkout is explicitly out
-- of scope), so this is a flat limit for every provider today.
create or replace function public.check_photo_limit()
returns trigger
language plpgsql
as $$
begin
  if (select count(*) from public.provider_photos where provider_id = new.provider_id) >= 5 then
    raise exception 'validation_failed: free listings may publish at most 5 photos';
  end if;
  return new;
end;
$$;

create trigger trg_photo_limit
  before insert on public.provider_photos
  for each row execute function public.check_photo_limit();
