-- Optional business map location, and recorded acceptance of the Terms.
--
-- Untested like the rest of this backend: run `supabase db reset` and
-- `supabase test db` before relying on it.

alter type public.consent_kind add value if not exists 'show_map_location';
alter type public.consent_kind add value if not exists 'terms_accepted';

-- A pin exists only while the provider has opted in. Withdrawing consent sets
-- both columns to null, so the coordinates are deleted rather than hidden.
-- This matters because published rows are readable by anyone (0009_rls.sql):
-- nothing the provider has not chosen to publish may sit in them.
alter table public.provider_profiles
  add column map_lat double precision,
  add column map_lng double precision,
  add constraint provider_map_location_both_or_neither
    check ((map_lat is null) = (map_lng is null)),
  add constraint provider_map_location_in_range
    check (map_lat is null or (map_lat between -90 and 90 and map_lng between -180 and 180));

-- Owner sets (or, with nulls, clears) the pin and records the consent change
-- in one call.
create or replace function public.set_map_location(
  p_profile_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_phone text;
begin
  select user_id, phone_e164 into v_owner, v_phone
  from public.provider_profiles where id = p_profile_id;
  if v_owner is null then
    raise exception 'not_found: profile not found';
  end if;
  if v_owner is distinct from auth.uid() then
    raise exception 'not_owner: cannot edit another provider''s profile';
  end if;
  if (p_lat is null) <> (p_lng is null) then
    raise exception 'validation: give both coordinates or neither';
  end if;

  update public.provider_profiles
  set map_lat = p_lat, map_lng = p_lng, updated_at = now()
  where id = p_profile_id;

  insert into public.consent_records (provider_id, kind, granted, phone_e164)
  values (p_profile_id, 'show_map_location', p_lat is not null, v_phone);
end;
$$;

-- Records that the owner accepted a given version of the Terms and Privacy
-- Policy (and confirmed being 18+). Called once after registration, and again
-- whenever a new version is accepted.
create or replace function public.record_terms_acceptance(
  p_profile_id uuid,
  p_version text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_phone text;
begin
  select user_id, phone_e164 into v_owner, v_phone
  from public.provider_profiles where id = p_profile_id;
  if v_owner is null or v_owner is distinct from auth.uid() then
    raise exception 'not_owner: cannot accept terms for another provider';
  end if;
  if coalesce(btrim(p_version), '') = '' then
    raise exception 'validation: terms version required';
  end if;

  insert into public.consent_records (provider_id, kind, granted, phone_e164, wording_version)
  values (p_profile_id, 'terms_accepted', true, v_phone, p_version);
end;
$$;

-- Add mapLocation to the profile JSON every read path returns. Wrapping the
-- original (renamed) keeps this migration small; callers resolve the name at
-- run time, so they all pick up the wrapper.
alter function public.provider_profile_json(uuid) rename to provider_profile_json_core;

create function public.provider_profile_json(p_id uuid)
returns jsonb
language sql
stable
as $$
  select public.provider_profile_json_core(p_id) || jsonb_build_object(
    'mapLocation',
    (select case when pp.map_lat is null then null
                 else jsonb_build_object('lat', pp.map_lat, 'lng', pp.map_lng) end
     from public.provider_profiles pp where pp.id = p_id)
  );
$$;
