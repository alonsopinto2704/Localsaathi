-- 0023: audit follow-up fixes (2026-10-07 re-audit).
-- Kill-switch gaps (sponsored placement in search, healthcare, precise location),
-- revision-cap race, payload validation holes, audit regex alignment, city-request ceiling.

-- 1. sponsored_placement also gates the sponsor boost inside search.
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
      where public.flag_enabled('sponsored_placement')
        and pr.state = 'active'
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

-- 2. Public projection honours healthcare_listings and precise_location.
create or replace function public.public_profile_json(p_id uuid)
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
    -- Contact fields exist only under current consent and the contact kill switch.
    'phoneE164', case when pp.phone_display_consented and public.flag_enabled('contact_reveal') then pp.phone_e164 end,
    'phoneDisplayConsented', pp.phone_display_consented,
    'whatsappEnabled', pp.whatsapp_enabled and pp.phone_display_consented and public.flag_enabled('contact_reveal'),
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
          'id', ph.id, 'caption', ph.caption, 'remoteUrl', ph.remote_url,
          -- Only profile-keyed paths are public; a legacy <user_id>/ path would leak the auth id.
          'storagePath', case when ph.storage_path like pp.id::text || '/%' then ph.storage_path end,
          'isPlaceholder', ph.is_placeholder, 'uploadedAt', ph.uploaded_at)
        order by ph.uploaded_at)
      from public.provider_photos ph where ph.provider_id = pp.id), '[]'::jsonb),
    'startingPrices', coalesce((
      select jsonb_agg(jsonb_build_object('categoryId', sp.category_id, 'amount', sp.amount_rupees, 'note', sp.note)
        order by sp.category_id)
      from public.provider_starting_prices sp
      join public.service_categories sc on sc.id = sp.category_id and sc.is_approved_for_launch
      where sp.provider_id = pp.id), '[]'::jsonb),
    'healthcareDetails', case when public.flag_enabled('healthcare_listings') then (
      select jsonb_build_object(
        'qualification', hd.qualification, 'specialty', hd.specialty,
        'clinicName', hd.clinic_name, 'clinicAddress', hd.clinic_address,
        'consultationHoursNote', hd.consultation_hours_note,
        'registrationNumber', hd.registration_number, 'registrationCouncil', hd.registration_council,
        'isDiagnosticCentre', hd.is_diagnostic_centre, 'acceptsWalkIns', hd.accepts_walk_ins)
      from public.provider_healthcare_details hd where hd.provider_id = pp.id) end,
    'homeVisits', pp.home_visits,
    'availability', pp.availability,
    'verification', coalesce((
      select jsonb_object_agg(v.kind, v.status) from (
        select distinct on (kind) kind, status from public.verification_records
        where provider_id = pp.id order by kind, created_at desc) v
      where v.status = 'approved'), '{}'::jsonb),
    'pinCodes', to_jsonb(pp.pin_codes),
    'mapLocation', case when pp.map_lat is null or not public.flag_enabled('precise_location') then null
                        else jsonb_build_object('lat', round(pp.map_lat::numeric, 2), 'lng', round(pp.map_lng::numeric, 2)) end
  )
  from public.provider_profiles pp
  where pp.id = p_id;
$$;

revoke execute on function public.public_profile_json(uuid) from public, anon, authenticated;

-- 3. Payload validation: service-area pin codes and language length.
create or replace function private.validate_payload_shape(p jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  k text;
begin
  if p is null or jsonb_typeof(p) <> 'object' then
    raise exception 'validation_failed: payload must be an object';
  end if;
  foreach k in array array['categoryIds', 'serviceAreaIds', 'serviceAreas', 'languages', 'pinCodes', 'startingPrices'] loop
    if p ? k and jsonb_typeof(p->k) <> 'array' then
      raise exception 'validation_failed: % must be a list', k;
    end if;
  end loop;
  foreach k in array array['categoryIds', 'serviceAreaIds', 'languages', 'pinCodes'] loop
    if p ? k and exists (select 1 from jsonb_array_elements(p->k) e where jsonb_typeof(e) <> 'string') then
      raise exception 'validation_failed: % must contain only text', k;
    end if;
  end loop;
  if p ? 'pinCodes' and exists (select 1 from jsonb_array_elements_text(p->'pinCodes') x where x !~ '^[1-9][0-9]{5}$') then
    raise exception 'validation_failed: pin codes must be 6 digits';
  end if;
  foreach k in array array['serviceAreas', 'startingPrices'] loop
    if p ? k and exists (select 1 from jsonb_array_elements(p->k) e where jsonb_typeof(e) <> 'object') then
      raise exception 'validation_failed: % must contain objects', k;
    end if;
  end loop;
  if p ? 'startingPrices' and exists (
       select 1 from jsonb_array_elements(p->'startingPrices') e
       where nullif(e->>'categoryId', '') is null
          or (p ? 'categoryIds' and not (p->'categoryIds') ? (e->>'categoryId'))) then
    raise exception 'validation_failed: each starting price needs one of your categories';
  end if;
  if p ? 'serviceAreas' and exists (
       select 1 from jsonb_array_elements(p->'serviceAreas') e
       where e ? 'pinCodes' and (jsonb_typeof(e->'pinCodes') <> 'array'
              or jsonb_array_length(e->'pinCodes') > 20
              or exists (select 1 from jsonb_array_elements(e->'pinCodes') x
                         where jsonb_typeof(x) <> 'string' or (x #>> '{}') !~ '^[1-9][0-9]{5}$'))) then
    raise exception 'validation_failed: service area pin codes must be at most 20 six-digit codes';
  end if;
  if p ? 'languages' and exists (
       select 1 from jsonb_array_elements_text(p->'languages') x where char_length(x) not between 1 and 40) then
    raise exception 'validation_failed: each language is 1-40 characters';
  end if;
  if p ? 'workingHours' and jsonb_typeof(p->'workingHours') not in ('object', 'null') then
    raise exception 'validation_failed: workingHours must be an object';
  end if;
  if jsonb_typeof(p->'workingHours'->'days') = 'array' and exists (
       select 1 from jsonb_array_elements(p->'workingHours'->'days') d where jsonb_typeof(d) <> 'object') then
    raise exception 'validation_failed: workingHours.days must contain objects';
  end if;
  foreach k in array array['displayName', 'description'] loop
    if p ? k and jsonb_typeof(p->k) not in ('string', 'null') then
      raise exception 'validation_failed: % must be text', k;
    end if;
  end loop;
  if p ? 'healthcareDetails' and jsonb_typeof(p->'healthcareDetails') = 'object' and exists (
       select 1 from jsonb_each_text(p->'healthcareDetails') f where char_length(f.value) > 300) then
    raise exception 'validation_failed: healthcare details are limited to 300 characters per field';
  end if;
end;
$$;


-- 4. Wrappers: healthcare flag on writes; revision base read under the row lock;
-- starting prices tied to the listing's categories.
create or replace function public.register_profile(p_submission jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_flag('provider_signup');
  perform private.validate_payload_shape(p_submission);
  if jsonb_typeof(p_submission->'healthcareDetails') = 'object' then
    perform private.require_flag('healthcare_listings');
  end if;
  return private.register_profile_impl(p_submission);
exception
  when invalid_parameter_value or invalid_text_representation or datatype_mismatch
    or numeric_value_out_of_range or not_null_violation or check_violation then
    raise exception 'validation_failed: a field has the wrong type or value';
  when foreign_key_violation then
    raise exception 'validation_failed: unknown category or locality';
end;
$$;


create or replace function public.update_profile_full(p_profile_id uuid, p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
begin
  perform private.validate_payload_shape(p_patch);
  if jsonb_typeof(p_patch->'healthcareDetails') = 'object' then
    perform private.require_flag('healthcare_listings');
  end if;
  -- Lock (and authorise) first, so the revision base is read under the row lock.
  v_row := private.lock_owned_profile(p_profile_id, null);
  perform set_config('localsaathi.revision_base', p_profile_id::text || ':' || v_row.revision::text, true);
  perform private.update_profile_full_impl(p_profile_id, p_patch);
  perform set_config('localsaathi.revision_base', '', true);
  -- Starting prices must belong to the listing's categories, whichever side of the patch changed.
  if p_patch ? 'startingPrices' and exists (
       select 1 from public.provider_starting_prices sp
       where sp.provider_id = p_profile_id and not exists (
         select 1 from public.provider_categories pc
         where pc.provider_id = p_profile_id and pc.category_id = sp.category_id)) then
    raise exception 'validation_failed: each starting price needs one of your categories';
  end if;
  delete from public.provider_starting_prices sp
  where sp.provider_id = p_profile_id and not exists (
    select 1 from public.provider_categories pc
    where pc.provider_id = p_profile_id and pc.category_id = sp.category_id);
  perform private.assert_still_publishable(p_profile_id);
  return public.provider_profile_json(p_profile_id);
exception
  when invalid_parameter_value or invalid_text_representation or datatype_mismatch
    or numeric_value_out_of_range or not_null_violation or check_violation then
    raise exception 'validation_failed: a field has the wrong type or value';
  when foreign_key_violation then
    raise exception 'validation_failed: unknown category or locality';
end;
$$;

-- 5. Audit.
create or replace function private.write_audit(
  p_action text, p_target_type text, p_target_id text,
  p_reason text default null, p_details jsonb default '{}'
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_headers jsonb := nullif(current_setting('request.headers', true), '')::jsonb;
  v_text text;
  v_id bigint;
begin
  -- Drop ids and ISO timestamps (expected in details), then join digits
  -- separated by phone formatting, then look for a phone-length digit run.
  v_text := coalesce(p_details, '{}')::text || ' ' || coalesce(p_reason, '');
  v_text := regexp_replace(v_text, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', ' ', 'g');
  v_text := regexp_replace(v_text, '\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?([+-]\d{2}(:?\d{2})?|Z)?', ' ', 'g');
  v_text := regexp_replace(v_text, '(\d)[\s().-]+(?=\d)', '\1', 'g');
  -- E.164 (+ and 8-15 digits) or an Indian mobile ([6-9] + 9 digits, optional 91/0);
  -- a unix epoch (starts with 1) or other ids are not phone-shaped.
  if v_text ~ '\+[1-9]\d{7,14}' or v_text ~ '(^|[^0-9])(91|0)?[6-9]\d{9}([^0-9]|$)' then
    raise exception 'audit_redaction: details or reason contain a phone-like number';
  end if;
  insert into private.audit_events (actor_id, actor_role, action, target_type, target_id, reason, correlation_id, details)
  values (
    auth.uid(), auth.role(), p_action, p_target_type, p_target_id, nullif(btrim(p_reason), ''),
    coalesce(v_headers->>'x-request-id', v_headers->>'x-correlation-id', gen_random_uuid()::text),
    coalesce(p_details, '{}')
  )
  returning id into v_id;
  return v_id;
end;
$$;


create or replace function private.audit_admin_table_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb := to_jsonb(coalesce(new, old));
begin
  if auth.uid() is null then
    return coalesce(new, old); -- service role / migrations: not an admin action
  end if;
  perform private.write_audit(
    tg_table_name || '_' || lower(tg_op), tg_table_name, v_row->>'id', v_row->>'resolution_note',
    case tg_table_name
      when 'reports' then jsonb_build_object('status', v_row->>'status')
      else jsonb_build_object('provider_id', v_row->>'provider_id', 'state', v_row->>'state')
    end);
  return coalesce(new, old);
end;
$$;

-- 6. media_intake also gates photo deletion; global ceiling on city requests.
create or replace function public.delete_provider_photo(p_photo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid;
begin
  select provider_id into v_profile_id from public.provider_photos where id = p_photo_id;
  if v_profile_id is null then
    raise exception 'not_found: photo not found';
  end if;
  perform private.require_flag('media_intake');
  perform private.lock_owned_profile(v_profile_id, null);
  delete from public.provider_photos where id = p_photo_id;
  update public.provider_profiles set updated_at = now() where id = v_profile_id;
  return public.provider_profile_json(v_profile_id);
end;
$$;

create or replace function public.request_city(p_city_name text, p_state_name text default null, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source text := private.request_source();
  v_id uuid;
begin
  if char_length(btrim(coalesce(p_city_name, ''))) not between 2 and 80
     or char_length(coalesce(p_state_name, '')) > 80
     or char_length(coalesce(p_note, '')) > 500 then
    raise exception 'validation_failed: city 2-80 characters, state up to 80, note up to 500';
  end if;
  if not private.take_rate_token('city_request:source:d', coalesce(v_source, 'no-source'), interval '1 day',
                                  case when v_source is null then 200 else 5 end) then
    raise exception 'rate_limited: too many requests today';
  end if;
  -- Rotating source headers cannot get past a global hourly ceiling.
  if not private.take_rate_token('city_request:all:h', 'all', interval '1 hour', 300) then
    raise exception 'rate_limited: too many requests, try again later';
  end if;
  insert into public.city_requests (city_name, state_name, note, submitted_by_phone)
  values (btrim(p_city_name), nullif(btrim(p_state_name), ''), nullif(btrim(p_note), ''),
          -- Only ever the signed-in provider's own verified number, never client input.
          (select phone_e164 from public.provider_profiles where user_id = auth.uid()))
  returning id into v_id;
  return jsonb_build_object('receiptId', v_id, 'status', 'received');
end;
$$;

