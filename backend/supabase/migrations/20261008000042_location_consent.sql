-- 0042: phase 091, precise location consent.
--
-- Three different things used to share one pair of columns (map_lat/map_lng):
--   public business address   provider-stated text (healthcare clinicAddress),
--                             public only because the provider typed it there;
--   approximate service area  the base locality and service areas, always public;
--   residential coordinates   map_lat/map_lng, a home-based provider's own pin.
-- Before: setting a pin wrote a generic consent row and the pin was public
-- (rounded to ~1 km) as soon as the precise_location flag was on; there was no
-- way to say "area search only", and the stored pin was exact.
--
-- After:
--   * location_mode is 'locality_only' (default: no coordinates leave the
--     database) or 'approximate_pin'. A pin is public only in approximate_pin
--     mode, only while precise_location is on, and never finer than 2 decimals.
--   * The pin is rounded to that precision when it is STORED, so an exact home
--     coordinate is never kept (data minimisation), and every consumer (maps,
--     search, similar lists, exports built from the public shape, AI context
--     built from the public shape) sees the same value.
--   * Turning the mode on needs the current wording version ('location-v2') and
--     is recorded as a consent row; turning it off deletes the coordinates and
--     records the withdrawal. Existing rows start as 'locality_only', so every
--     pin that predates this wording is hidden until its owner opts in again.

alter table public.provider_profiles
  add column location_mode text not null default 'locality_only'
    check (location_mode in ('locality_only', 'approximate_pin')),
  add column location_consent_version text,
  add column location_consented_at timestamptz;

create function private.location_overlay(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('mapLocation',
    case when pp.map_lat is not null and pp.location_mode = 'approximate_pin' and public.flag_enabled('precise_location')
         then jsonb_build_object('lat', round(pp.map_lat::numeric, 2), 'lng', round(pp.map_lng::numeric, 2)) end)
  from public.provider_profiles pp where pp.id = p_id;
$$;

create or replace function public.public_profile_json(p_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select private.public_profile_json_base(p_id) || private.trust_overlay(p_id) || private.location_overlay(p_id);
$$;

create function public.set_location_disclosure(
  p_profile_id uuid, p_mode text, p_lat double precision default null, p_lng double precision default null,
  p_consent_version text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
  v_on boolean := p_mode = 'approximate_pin';
begin
  if p_mode is null or p_mode not in ('locality_only', 'approximate_pin') then
    raise exception 'validation_failed: location mode must be locality_only or approximate_pin';
  end if;
  if v_on then
    perform private.require_flag('precise_location');
    if p_consent_version is distinct from 'location-v2' then
      raise exception 'consent_required: accept the current location wording before sharing an approximate pin';
    end if;
    if p_lat is null or p_lng is null or p_lat not between 6 and 38 or p_lng not between 68 and 98 then
      raise exception 'validation_failed: give both coordinates, inside India';
    end if;
  end if;
  v_row := private.lock_owned_profile(p_profile_id, null);
  if not private.take_rate_token('consent:' || p_profile_id, 'map', interval '1 hour', 30) then
    raise exception 'rate_limited: too many location changes, try again later';
  end if;
  update public.provider_profiles set
    location_mode = p_mode,
    map_lat = case when v_on then round(p_lat::numeric, 2)::double precision end,
    map_lng = case when v_on then round(p_lng::numeric, 2)::double precision end,
    location_consent_version = case when v_on then p_consent_version end,
    location_consented_at = case when v_on then now() end
  where id = p_profile_id;
  insert into public.consent_records (provider_id, kind, granted, phone_e164, wording_version, withdrawn_at)
  values (p_profile_id, 'show_map_location', v_on, v_row.phone_e164,
          case when v_on then p_consent_version else 'location-v2' end, case when v_on then null else now() end);
  return jsonb_build_object('mode', p_mode, 'hasPin', v_on);
end;
$$;

-- The old setter accepted any coordinates under a generic consent. It can now
-- only remove a pin; sharing one goes through set_location_disclosure.
create or replace function public.set_map_location(p_profile_id uuid, p_lat double precision, p_lng double precision)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_lat is not null or p_lng is not null then
    raise exception 'validation_failed: use set_location_disclosure to share an approximate pin';
  end if;
  perform public.set_location_disclosure(p_profile_id, 'locality_only');
end;
$$;

create function public.get_location_settings(p_profile_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'mode', pp.location_mode, 'hasPin', pp.map_lat is not null,
    'consentVersion', pp.location_consent_version, 'consentedAt', pp.location_consented_at,
    'currentConsentVersion', 'location-v2',
    'needsReconsent', pp.location_mode <> 'locality_only' and pp.location_consent_version is distinct from 'location-v2')
  from public.provider_profiles pp
  where pp.id = p_profile_id and pp.user_id = auth.uid();
$$;

revoke execute on function
  public.set_location_disclosure(uuid, text, double precision, double precision, text),
  public.get_location_settings(uuid), private.location_overlay(uuid)
  from public, anon, authenticated;
grant execute on function
  public.set_location_disclosure(uuid, text, double precision, double precision, text),
  public.get_location_settings(uuid)
  to authenticated;
