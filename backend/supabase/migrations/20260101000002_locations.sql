-- Location hierarchy: Country -> State/UT -> City -> Locality.
--
-- Mirrors lib/domain/models/location.dart and lib/domain/repositories/
-- location_repository.dart exactly, so Antigravity's existing LocationRepository
-- method shapes map onto these tables without renaming anything on the client.
--
-- `cities.launch_status` is the single switch the whole product reads to
-- decide whether a market is browsable/registerable. Activating Thane or
-- Navi Mumbai later is one UPDATE here, never a code change on either side.

create table public.countries (
  id text primary key,
  name text not null,
  iso_code text not null unique,
  dial_code text not null,
  is_active boolean not null default true
);

create table public.state_regions (
  id text primary key,
  country_id text not null references public.countries(id),
  name text not null,
  is_union_territory boolean not null default false,
  is_active boolean not null default true
);

create type public.city_launch_status as enum ('active', 'coming_soon', 'inactive');

create table public.cities (
  id text primary key,
  state_id text not null references public.state_regions(id),
  name text not null,
  launch_status public.city_launch_status not null default 'inactive',
  aliases text[] not null default '{}',
  is_metro boolean not null default false
);

create table public.localities (
  id text primary key,
  city_id text not null references public.cities(id),
  name text not null,
  -- Indicative only, as in the client model: a locality can span several PIN
  -- codes, so this is never used as an identifier.
  pin_code text,
  is_popular boolean not null default false
);

-- "Please open my city" requests. Writable by anyone (guests included);
-- readable by the requester (when signed in) and admins only -- these are not
-- a public directory of who asked for what.
create table public.city_requests (
  id uuid primary key default gen_random_uuid(),
  city_name text not null,
  state_name text,
  note text,
  submitted_by_phone text,
  requested_at timestamptz not null default now()
);

comment on column public.cities.launch_status is
  'active = browsable + registerable; coming_soon = visible in picker only; '
  'inactive = present in data, hidden from picker. Changing this is the whole '
  'mechanism for activating a new market.';
