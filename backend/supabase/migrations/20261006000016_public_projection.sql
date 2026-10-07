-- Phases 022 (allowlisted public projection), 028 (every discovery path
-- honours market activation), 031 (open-now semantics), 034 (search bounds).
--
-- Before: public paths returned provider_profile_json() (the OWNER shape)
-- minus 'moderationStatus' -- a blocklist, so every new column or key became
-- public by default, phoneE164 was returned whatever the consent, the exact
-- map pin and rejected/pending credential states were public, and LIMIT was
-- unbounded. After: public_profile_json() names every public key; anything
-- not listed here never leaves the database through a public call.

-- ---------------------------------------------------------------------------
-- 031: one open-now rule (mirrors WorkingHours.isOpenAt in Dart; fixtures in
-- docs/contracts/fixtures/working-hours.json). t_* = today's row, y_* =
-- yesterday's row, m = India wall-clock minutes since midnight.
create function private.hours_open(t_open int, t_close int, y_open int, y_close int, m int)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    (t_open is not null and t_close is not null and (
       (t_close <= t_open and m >= t_open)
       or (t_close > t_open and m >= t_open and (m < t_close or t_close = 1439))
    ))
    or (y_open is not null and y_close is not null and y_close <= y_open and m < y_close),
    false);
$$;

-- 034: user text is matched literally, never as a LIKE pattern.
create function private.like_contains(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select '%' || replace(replace(replace(p_text, '\', '\\'), '%', '\%'), '_', '\_') || '%';
$$;

-- ---------------------------------------------------------------------------
-- 022: the public shape. Only call for a listing that is_publicly_listed().
create function public.public_profile_json(p_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', pp.id,
    'displayName', pp.display_name,
    'baseCityId', pp.base_city_id,
    'baseLocalityId', pp.base_locality_id,
    'status', pp.status,
    'createdAt', pp.created_at,
    'updatedAt', pp.updated_at,
    -- Contact fields exist only under current consent.
    'phoneE164', case when pp.phone_display_consented then pp.phone_e164 end,
    'phoneDisplayConsented', pp.phone_display_consented,
    'whatsappEnabled', pp.whatsapp_enabled and pp.phone_display_consented,
    'categoryIds', coalesce((
      select jsonb_agg(pc.category_id order by pc.category_id)
      from public.provider_categories pc
      join public.service_categories sc on sc.id = pc.category_id and sc.is_approved_for_launch
      where pc.provider_id = pp.id), '[]'::jsonb),
    'serviceAreas', coalesce((
      select jsonb_agg(jsonb_build_object(
          'cityId', sa.city_id, 'localityId', sa.locality_id,
          'pinCodes', to_jsonb(sa.pin_codes), 'isPrimary', sa.is_primary)
        order by sa.locality_id)
      from public.provider_service_areas sa where sa.provider_id = pp.id), '[]'::jsonb),
    'description', pp.description,
    'languages', to_jsonb(pp.languages),
    'workingHours', (
      select case when count(*) = 0 then null else jsonb_build_object(
        'days', jsonb_agg(jsonb_build_object('weekday', wh.weekday, 'open', wh.open_minutes, 'close', wh.close_minutes)
                          order by wh.weekday)) end
      from public.provider_working_hours wh where wh.provider_id = pp.id),
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', ph.id, 'caption', ph.caption, 'remoteUrl', ph.remote_url, 'storagePath', ph.storage_path,
          'isPlaceholder', ph.is_placeholder, 'uploadedAt', ph.uploaded_at)
        order by ph.uploaded_at)
      from public.provider_photos ph where ph.provider_id = pp.id), '[]'::jsonb),
    'startingPrices', coalesce((
      select jsonb_agg(jsonb_build_object('categoryId', sp.category_id, 'amount', sp.amount_rupees, 'note', sp.note)
        order by sp.category_id)
      from public.provider_starting_prices sp
      join public.service_categories sc on sc.id = sp.category_id and sc.is_approved_for_launch
      where sp.provider_id = pp.id), '[]'::jsonb),
    'healthcareDetails', (
      select jsonb_build_object(
        'qualification', hd.qualification, 'specialty', hd.specialty,
        'clinicName', hd.clinic_name, 'clinicAddress', hd.clinic_address,
        'consultationHoursNote', hd.consultation_hours_note,
        'registrationNumber', hd.registration_number, 'registrationCouncil', hd.registration_council,
        'isDiagnosticCentre', hd.is_diagnostic_centre, 'acceptsWalkIns', hd.accepts_walk_ins)
      from public.provider_healthcare_details hd where hd.provider_id = pp.id),
    'homeVisits', pp.home_visits,
    'availability', pp.availability,
    -- Only positive, checked facts are public: phone control always, a
    -- credential only once a reviewer approved it. Pending/rejected states
    -- are between the provider and moderators.
    'verification', coalesce((
      select jsonb_object_agg(v.kind, v.status) from (
        select distinct on (kind) kind, status from public.verification_records
        where provider_id = pp.id order by kind, created_at desc) v
      where v.status = 'approved'), '{}'::jsonb),
    'pinCodes', to_jsonb(pp.pin_codes),
    -- Approximate only (~1 km): residential pins must not be pinpointable.
    'mapLocation', case when pp.map_lat is null then null
                        else jsonb_build_object('lat', round(pp.map_lat::numeric, 2), 'lng', round(pp.map_lng::numeric, 2)) end
  )
  from public.provider_profiles pp
  where pp.id = p_id;
$$;
revoke execute on function public.public_profile_json(uuid) from public, anon, authenticated;

-- Owner shape: unchanged keys plus what an owner needs to understand why a
-- listing is (not) visible and which revision they are editing.
create or replace function public.provider_profile_json(p_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select public.provider_profile_json_core(p_id) || jsonb_build_object(
    'mapLocation', case when pp.map_lat is null then null
                        else jsonb_build_object('lat', pp.map_lat, 'lng', pp.map_lng) end,
    'revision', pp.revision,
    'isPubliclyListed', public.is_publicly_listed(pp.id)
  )
  from public.provider_profiles pp where pp.id = p_id;
$$;

-- ---------------------------------------------------------------------------
-- Public read paths, all gated by is_publicly_listed().
create or replace function public.get_public_profile(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_publicly_listed(p_id) then public.public_profile_json(p_id) end;
$$;

create or replace function public.search_providers(
  p_city_id text,
  p_locality_id text,
  p_text text default '',
  p_category_ids text[] default '{}',
  p_locality_filter_ids text[] default '{}',
  p_open_now_only boolean default false,
  p_home_visits_only boolean default false,
  p_limit int default 20,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_text text := btrim(coalesce(p_text, ''));
  v_pattern text;
  v_target_localities text[];
  v_now timestamptz := now();
  v_ist timestamp := v_now at time zone 'Asia/Kolkata';
  v_weekday int := extract(isodow from v_ist)::int;
  v_yesterday int := case when extract(isodow from v_ist)::int = 1 then 7 else extract(isodow from v_ist)::int - 1 end;
  v_minutes int := extract(hour from v_ist)::int * 60 + extract(minute from v_ist)::int;
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset int := greatest(coalesce(p_offset, 0), 0);
  v_category_text_ids text[];
begin
  -- 034: reject inputs that would make a public call expensive.
  if char_length(v_text) > 80 then
    raise exception 'validation_failed: search text is limited to 80 characters';
  end if;
  if coalesce(array_length(p_category_ids, 1), 0) > 20 or coalesce(array_length(p_locality_filter_ids, 1), 0) > 20 then
    raise exception 'validation_failed: at most 20 categories and 20 localities per search';
  end if;
  if v_offset > 500 then
    raise exception 'validation_failed: refine the search instead of paging past 500 results';
  end if;
  if p_city_id is null or p_locality_id is null then
    raise exception 'validation_failed: city and locality are required';
  end if;
  v_pattern := private.like_contains(v_text);

  v_target_localities := case
    when coalesce(array_length(p_locality_filter_ids, 1), 0) = 0 then array[p_locality_id]
    else p_locality_filter_ids
  end;

  if v_text <> '' then
    select coalesce(array_agg(sc.id), '{}') into v_category_text_ids
    from public.service_categories sc
    where sc.is_approved_for_launch and (
      sc.name ilike v_pattern
      or exists (select 1 from unnest(sc.keywords) k where k ilike v_pattern));
  end if;

  return (
    with matches as (
      select pp.*
      from public.provider_profiles pp
      where pp.status = 'published'
        and pp.moderation_status = 'active'
        and pp.base_city_id = p_city_id
        -- The authoritative rule (consent, active city, approved category,
        -- service area); the cheap column filters above narrow rows first.
        and public.is_publicly_listed(pp.id)
        and exists (
          select 1 from public.provider_service_areas sa
          where sa.provider_id = pp.id and sa.locality_id = any(v_target_localities))
        and exists (
          select 1 from public.provider_categories pc
          join public.service_categories sc on sc.id = pc.category_id and sc.is_approved_for_launch
          where pc.provider_id = pp.id
            and (coalesce(array_length(p_category_ids, 1), 0) = 0 or pc.category_id = any(p_category_ids)))
        and (not coalesce(p_home_visits_only, false) or pp.home_visits)
        and (not coalesce(p_open_now_only, false) or private.hours_open(
          (select wh.open_minutes from public.provider_working_hours wh where wh.provider_id = pp.id and wh.weekday = v_weekday),
          (select wh.close_minutes from public.provider_working_hours wh where wh.provider_id = pp.id and wh.weekday = v_weekday),
          (select wh.open_minutes from public.provider_working_hours wh where wh.provider_id = pp.id and wh.weekday = v_yesterday),
          (select wh.close_minutes from public.provider_working_hours wh where wh.provider_id = pp.id and wh.weekday = v_yesterday),
          v_minutes))
        and (
          v_text = ''
          or pp.display_name ilike v_pattern
          or coalesce(pp.description, '') ilike v_pattern
          or exists (select 1 from public.provider_categories pc
                     where pc.provider_id = pp.id and pc.category_id = any(v_category_text_ids))
          or exists (select 1 from public.provider_service_areas sa join public.localities l on l.id = sa.locality_id
                     where sa.provider_id = pp.id and l.name ilike v_pattern)
          or exists (select 1 from public.localities l where l.id = pp.base_locality_id and l.name ilike v_pattern))
    ),
    sponsor_matches as (
      select m.id as provider_id, max(pr.priority) as priority
      from matches m
      join public.promotions pr on pr.provider_id = m.id
      where pr.state = 'active'
        and v_now >= pr.starts_at and v_now < pr.ends_at
        and (pr.city_id is null or pr.city_id = p_city_id)
        and (coalesce(array_length(pr.locality_ids, 1), 0) = 0 or p_locality_id = any(pr.locality_ids))
        and (coalesce(array_length(pr.category_ids, 1), 0) = 0
             or coalesce(array_length(p_category_ids, 1), 0) = 0
             or pr.category_ids && p_category_ids)
      group by m.id
    ),
    ranked as (
      select m.id, m.display_name,
        (sm.provider_id is not null) as is_sponsored,
        coalesce(sm.priority, -1) as sponsor_priority,
        (select count(*) from public.provider_photos ph where ph.provider_id = m.id) as photo_count,
        (select count(*) from public.provider_categories pc where pc.provider_id = m.id) as category_count
      from matches m
      left join sponsor_matches sm on sm.provider_id = m.id
    ),
    paged as (
      select * from ranked
      order by is_sponsored desc, sponsor_priority desc, photo_count desc, category_count desc,
               display_name asc, id asc
      limit v_limit offset v_offset
    )
    select jsonb_build_object(
      'totalCount', (select count(*) from ranked),
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
            'isSponsored', paged.is_sponsored,
            'provider', public.public_profile_json(paged.id))
          order by paged.is_sponsored desc, paged.sponsor_priority desc, paged.photo_count desc,
                   paged.category_count desc, paged.display_name asc, paged.id asc)
        from paged), '[]'::jsonb))
  );
end;
$$;

create or replace function public.similar_providers(p_provider_id uuid, p_limit int default 6)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with target as (
    select pp.base_city_id,
      (select array_agg(category_id) from public.provider_categories where provider_id = pp.id) as category_ids,
      (select array_agg(locality_id) from public.provider_service_areas where provider_id = pp.id) as locality_ids
    from public.provider_profiles pp
    where pp.id = p_provider_id and public.is_publicly_listed(pp.id)
  ),
  picked as (
    select pp.id, pp.display_name
    from public.provider_profiles pp, target t
    where pp.id <> p_provider_id
      and pp.base_city_id = t.base_city_id
      and pp.status = 'published' and pp.moderation_status = 'active'
      and exists (select 1 from public.provider_categories pc where pc.provider_id = pp.id and pc.category_id = any(t.category_ids))
      and exists (select 1 from public.provider_service_areas sa where sa.provider_id = pp.id and sa.locality_id = any(t.locality_ids))
      and public.is_publicly_listed(pp.id)
    order by pp.display_name, pp.id
    limit least(greatest(coalesce(p_limit, 6), 1), 12)
  )
  select coalesce(jsonb_agg(public.public_profile_json(id) order by display_name, id), '[]'::jsonb) from picked;
$$;

create or replace function public.provider_count_by_locality(p_city_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(x.locality_id, x.cnt), '{}'::jsonb)
  from (
    select sa.locality_id, count(distinct sa.provider_id) as cnt
    from public.provider_service_areas sa
    join public.provider_profiles pp on pp.id = sa.provider_id
    where pp.base_city_id = p_city_id and pp.status = 'published' and pp.moderation_status = 'active'
      and public.is_publicly_listed(pp.id)
    group by sa.locality_id
  ) x;
$$;

-- Bounded: the Mumbai launch is a few hundred listings. Callers needing more
-- must page through search_providers.
create or replace function public.providers_published_in_city(p_city_id text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with picked as (
    select pp.id, pp.display_name from public.provider_profiles pp
    where pp.base_city_id = p_city_id and pp.status = 'published' and pp.moderation_status = 'active'
      and public.is_publicly_listed(pp.id)
    order by pp.display_name, pp.id
    limit 500
  )
  select coalesce(jsonb_agg(public.public_profile_json(id) order by display_name, id), '[]'::jsonb) from picked;
$$;

-- Adds 'state' (the client parsed every promotion as draft without it) and
-- only surfaces promotions of publicly listed providers.
create or replace function public.active_promotions(
  p_city_id text, p_locality_id text default null, p_category_id text default null,
  p_placement public.promotion_placement default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', pr.id, 'providerId', pr.provider_id, 'placement', pr.placement, 'state', pr.state,
      'startsAt', pr.starts_at, 'endsAt', pr.ends_at, 'priority', pr.priority
    ) order by pr.priority desc, pr.id), '[]'::jsonb)
  from public.promotions pr
  where pr.state = 'active'
    and now() >= pr.starts_at and now() < pr.ends_at
    and (p_placement is null or pr.placement = p_placement)
    and (pr.city_id is null or pr.city_id = p_city_id)
    and (coalesce(array_length(pr.locality_ids, 1), 0) = 0 or p_locality_id is null or p_locality_id = any(pr.locality_ids))
    and (coalesce(array_length(pr.category_ids, 1), 0) = 0 or p_category_id is null or p_category_id = any(pr.category_ids))
    and public.is_publicly_listed(pr.provider_id);
$$;

create or replace function public.search_cities(p_text text, p_country_id text default 'in')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_text text := btrim(coalesce(p_text, ''));
begin
  if char_length(v_text) > 80 then
    raise exception 'validation_failed: search text is limited to 80 characters';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', c.id, 'stateId', c.state_id, 'name', c.name,
        'launchStatus', c.launch_status, 'aliases', to_jsonb(c.aliases), 'isMetro', c.is_metro
      ) order by c.name), '[]'::jsonb)
    from (
      select c.* from public.cities c
      join public.state_regions sr on sr.id = c.state_id
      where sr.country_id = p_country_id and v_text <> '' and c.launch_status <> 'inactive' and (
        c.name ilike private.like_contains(v_text)
        or exists (select 1 from unnest(c.aliases) a where a ilike private.like_contains(v_text)))
      order by c.name limit 50
    ) c
  );
end;
$$;

create or replace function public.search_categories(p_text text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_text text := btrim(coalesce(p_text, ''));
begin
  if char_length(v_text) > 80 then
    raise exception 'validation_failed: search text is limited to 80 characters';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
        'id', sc.id, 'groupId', sc.group_id, 'name', sc.name, 'iconKey', sc.icon_key,
        'sortOrder', sc.sort_order, 'isHealthcare', sc.is_healthcare
      ) order by sc.sort_order), '[]'::jsonb)
    from (
      select * from public.service_categories sc
      where v_text <> '' and sc.is_approved_for_launch and (
        sc.name ilike private.like_contains(v_text)
        or exists (select 1 from unnest(sc.keywords) k where k ilike private.like_contains(v_text)))
      order by sc.sort_order limit 50
    ) sc
  );
end;
$$;

-- 0013's grants reference these signatures; create or replace keeps them.
