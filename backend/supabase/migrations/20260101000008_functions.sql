-- Business-rule functions: the publish/moderation gate, profile JSON
-- builders, search, registration, and the handful of admin-only actions.
--
-- Design choice: these live as plain SQL/PL/pgSQL functions + one trigger,
-- not a separate API server. Supabase's PostgREST + RPC already gives the
-- Flutter client a callable surface (supabase.rpc('search_providers', ...)),
-- and Postgres RLS (0009_rls.sql) is the actual enforcement layer underneath
-- every one of them. Running a Node/Express layer in front of this would
-- duplicate the authorization logic in a second place instead of having one
-- place that is impossible to bypass by going around it.

-- ---------------------------------------------------------------------------
-- 1. Publish/moderation gate.
--
-- Mirrors MockProviderRepository.publish()/updateProfile() and the
-- requirement that moderation_status can only ever move under an admin's
-- hand, never a provider's, regardless of which code path tries to change it
-- (RPC, direct table update, future admin tool).
create or replace function public.enforce_profile_mutation_rules()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and not public.is_admin() then
    if new.moderation_status is distinct from old.moderation_status then
      raise exception 'not_owner: only an administrator may change moderation status';
    end if;
    if new.suspension_reason is distinct from old.suspension_reason then
      raise exception 'not_owner: only an administrator may change the suspension reason';
    end if;
    if new.phone_e164 is distinct from old.phone_e164 then
      raise exception 'not_owner: phone number changes only through phone verification';
    end if;
  end if;

  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    if not new.phone_display_consented then
      raise exception 'listing_not_publishable: phone display consent is required to publish';
    end if;
    if new.display_name is null or btrim(new.display_name) = '' then
      raise exception 'validation_failed: display name is required to publish';
    end if;
    -- Checked on INSERT too, not just UPDATE: a direct insert of an
    -- already-published row (bypassing register_profile()) would otherwise
    -- skip this gate entirely, since on INSERT there is no prior row for a
    -- status-transition check to compare against.
    if not exists (
      select 1 from public.provider_categories where provider_id = new.id
    ) then
      raise exception 'validation_failed: at least one category is required to publish';
    end if;
    if not exists (
      select 1 from public.provider_service_areas where provider_id = new.id
    ) then
      raise exception 'validation_failed: at least one service area is required to publish';
    end if;
    if new.moderation_status = 'suspended' then
      raise exception 'suspended: a suspended listing cannot be published';
    end if;
    new.published_at = now();
  end if;

  if tg_op = 'UPDATE' then
    new.updated_at = now();
  end if;

  return new;
end;
$$;

create trigger trg_enforce_profile_mutation
  before insert or update on public.provider_profiles
  for each row execute function public.enforce_profile_mutation_rules();

-- ---------------------------------------------------------------------------
-- 2. Profile JSON builders.
--
-- One shape, reused everywhere a full profile is returned, so the public and
-- owner views cannot drift apart by accident. Field names match
-- ProviderProfile.toJson() in lib/domain/models/provider.dart; see
-- docs/backend-contract.md for the one intentional difference
-- (moderationStatus, stripped for the public view).
create or replace function public.provider_profile_json(p_id uuid)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', pp.id,
    'phoneE164', pp.phone_e164,
    'displayName', pp.display_name,
    'baseCityId', pp.base_city_id,
    'baseLocalityId', pp.base_locality_id,
    'status', pp.status,
    'moderationStatus', pp.moderation_status,
    'createdAt', pp.created_at,
    'updatedAt', pp.updated_at,
    'categoryIds', coalesce(
      (select jsonb_agg(pc.category_id) from public.provider_categories pc where pc.provider_id = pp.id),
      '[]'::jsonb
    ),
    'serviceAreas', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'cityId', sa.city_id,
          'localityId', sa.locality_id,
          'pinCodes', to_jsonb(sa.pin_codes),
          'isPrimary', sa.is_primary
        ))
       from public.provider_service_areas sa where sa.provider_id = pp.id),
      '[]'::jsonb
    ),
    'description', pp.description,
    'languages', to_jsonb(pp.languages),
    'workingHours', (
      select case when count(*) = 0 then null else jsonb_build_object(
        'days', jsonb_agg(
          jsonb_build_object('weekday', wh.weekday, 'open', wh.open_minutes, 'close', wh.close_minutes)
          order by wh.weekday
        )
      ) end
      from public.provider_working_hours wh where wh.provider_id = pp.id
    ),
    'photos', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'id', ph.id, 'caption', ph.caption, 'remoteUrl', ph.remote_url,
          'isPlaceholder', ph.is_placeholder, 'uploadedAt', ph.uploaded_at
        ))
       from public.provider_photos ph where ph.provider_id = pp.id),
      '[]'::jsonb
    ),
    'startingPrices', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'categoryId', sp.category_id, 'amount', sp.amount_rupees, 'note', sp.note
        ))
       from public.provider_starting_prices sp where sp.provider_id = pp.id),
      '[]'::jsonb
    ),
    'healthcareDetails', (
      select jsonb_build_object(
        'qualification', hd.qualification, 'specialty', hd.specialty,
        'clinicName', hd.clinic_name, 'clinicAddress', hd.clinic_address,
        'consultationHoursNote', hd.consultation_hours_note,
        'registrationNumber', hd.registration_number, 'registrationCouncil', hd.registration_council,
        'isDiagnosticCentre', hd.is_diagnostic_centre, 'acceptsWalkIns', hd.accepts_walk_ins
      )
      from public.provider_healthcare_details hd where hd.provider_id = pp.id
    ),
    'homeVisits', pp.home_visits,
    'availability', pp.availability,
    'whatsappEnabled', pp.whatsapp_enabled,
    'phoneDisplayConsented', pp.phone_display_consented,
    'verification', coalesce(
      (select jsonb_object_agg(v.kind, v.status) from (
         select distinct on (kind) kind, status from public.verification_records
         where provider_id = pp.id order by kind, created_at desc
       ) v),
      '{}'::jsonb
    ),
    'pinCodes', to_jsonb(pp.pin_codes)
  )
  from public.provider_profiles pp
  where pp.id = p_id;
$$;

-- Public (customer-facing) shape: same builder, minus the fields moderation
-- needs to track internally. Only returns anything for a listing that is
-- both published and not suspended -- a stale link to a paused, draft or
-- suspended profile returns null, matching
-- MockProviderRepository.publicProfileById().
create or replace function public.get_public_profile(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.provider_profile_json(pp.id) - 'moderationStatus'
  from public.provider_profiles pp
  where pp.id = p_id and pp.status = 'published' and pp.moderation_status = 'active';
$$;

-- Owner/admin shape: the full row, but only for the caller's own profile (or
-- any profile, for an admin). Enforced here in addition to RLS so a stale
-- client can never be confused about which guarantee applies.
create or replace function public.get_owner_profile(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.provider_profile_json(pp.id)
  from public.provider_profiles pp
  where pp.id = p_id and (pp.user_id = auth.uid() or public.is_admin());
$$;

-- ---------------------------------------------------------------------------
-- 3. Search.
--
-- Mirrors MockProviderRepository.search(): location always applies (base
-- locality OR a declared service area), category/home-visits/open-now are
-- optional filters, sponsored results are matched on the customer's own
-- city/locality/category and placed first (never hidden or reordering
-- organic results), then sorted phone-consent desc, photo count desc,
-- category count desc, name asc.
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
set search_path = public
as $$
declare
  v_target_localities text[];
  v_now timestamptz := now();
  v_ist timestamp := v_now at time zone 'Asia/Kolkata';
  -- ISO weekday 1=Monday..7=Sunday, matching DateTime.weekday in Dart.
  v_weekday int := extract(isodow from v_ist)::int;
  v_minutes int := extract(hour from v_ist)::int * 60 + extract(minute from v_ist)::int;
  v_category_text_ids text[];
  v_result jsonb;
begin
  v_target_localities := case
    when p_locality_filter_ids is null or array_length(p_locality_filter_ids, 1) is null
      then array[p_locality_id]
    else p_locality_filter_ids
  end;

  select coalesce(array_agg(sc.id), '{}') into v_category_text_ids
  from public.service_categories sc
  where btrim(p_text) <> '' and (
    sc.name ilike '%' || p_text || '%'
    or exists (select 1 from unnest(sc.keywords) k where k ilike '%' || p_text || '%')
  );

  with matches as (
    select pp.*
    from public.provider_profiles pp
    where pp.status = 'published'
      and pp.moderation_status = 'active'
      and pp.base_city_id = p_city_id
      and exists (
        select 1 from public.provider_service_areas sa
        where sa.provider_id = pp.id and sa.locality_id = any(v_target_localities)
      )
      and (
        p_category_ids is null or array_length(p_category_ids, 1) is null or exists (
          select 1 from public.provider_categories pc
          where pc.provider_id = pp.id and pc.category_id = any(p_category_ids)
        )
      )
      and (not p_home_visits_only or pp.home_visits)
      and (
        not p_open_now_only or exists (
          select 1 from public.provider_working_hours wh
          where wh.provider_id = pp.id and wh.weekday = v_weekday
            and wh.open_minutes is not null and wh.close_minutes is not null
            and (
              (wh.close_minutes > wh.open_minutes and v_minutes >= wh.open_minutes and v_minutes < wh.close_minutes)
              or (wh.close_minutes <= wh.open_minutes and (v_minutes >= wh.open_minutes or v_minutes < wh.close_minutes))
            )
        )
      )
      and (
        btrim(p_text) = ''
        or pp.display_name ilike '%' || p_text || '%'
        or coalesce(pp.description, '') ilike '%' || p_text || '%'
        or exists (
          select 1 from public.provider_categories pc
          where pc.provider_id = pp.id and pc.category_id = any(v_category_text_ids)
        )
        or exists (
          select 1 from public.provider_service_areas sa join public.localities l on l.id = sa.locality_id
          where sa.provider_id = pp.id and l.name ilike '%' || p_text || '%'
        )
        or exists (
          select 1 from public.localities l where l.id = pp.base_locality_id and l.name ilike '%' || p_text || '%'
        )
      )
  ),
  sponsor_matches as (
    select m.id as provider_id, max(pr.priority) as priority
    from matches m
    join public.promotions pr on pr.provider_id = m.id
    where pr.state = 'active'
      and v_now >= pr.starts_at and v_now < pr.ends_at
      and (pr.city_id is null or pr.city_id = p_city_id)
      and (array_length(pr.locality_ids, 1) is null or p_locality_id = any(pr.locality_ids))
      and (
        array_length(pr.category_ids, 1) is null
        or p_category_ids is null or array_length(p_category_ids, 1) is null
        or pr.category_ids && p_category_ids
      )
    group by m.id
  ),
  ranked as (
    select m.*,
      (sm.provider_id is not null) as is_sponsored,
      coalesce(sm.priority, -1) as sponsor_priority,
      (select count(*) from public.provider_photos ph where ph.provider_id = m.id) as photo_count,
      (select count(*) from public.provider_categories pc where pc.provider_id = m.id) as category_count
    from matches m
    left join sponsor_matches sm on sm.provider_id = m.id
  ),
  counted as (
    select count(*) as total_count from ranked
  ),
  paged as (
    select * from ranked
    order by is_sponsored desc, sponsor_priority desc,
             phone_display_consented desc, photo_count desc, category_count desc,
             display_name asc
    limit greatest(p_limit, 0) offset greatest(p_offset, 0)
  )
  select jsonb_build_object(
    'totalCount', (select total_count from counted),
    'items', coalesce(
      (select jsonb_agg(jsonb_build_object(
          'isSponsored', paged.is_sponsored,
          'provider', public.provider_profile_json(paged.id) - 'moderationStatus'
        ))
       from paged),
      '[]'::jsonb
    )
  ) into v_result;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Similar providers and locality counts.
create or replace function public.similar_providers(p_provider_id uuid, p_limit int default 6)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with target as (
    select base_city_id,
      (select array_agg(category_id) from public.provider_categories where provider_id = p_provider_id) as category_ids,
      (select array_agg(locality_id) from public.provider_service_areas where provider_id = p_provider_id) as locality_ids
    from public.provider_profiles where id = p_provider_id
  )
  select coalesce(jsonb_agg(public.provider_profile_json(pp.id) - 'moderationStatus' order by pp.display_name), '[]'::jsonb)
  from public.provider_profiles pp, target t
  where pp.id <> p_provider_id
    and pp.status = 'published' and pp.moderation_status = 'active'
    and pp.base_city_id = t.base_city_id
    and exists (select 1 from public.provider_categories pc where pc.provider_id = pp.id and pc.category_id = any(t.category_ids))
    and exists (select 1 from public.provider_service_areas sa where sa.provider_id = pp.id and sa.locality_id = any(t.locality_ids))
  limit p_limit;
$$;

create or replace function public.provider_count_by_locality(p_city_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_object_agg(sa.locality_id, cnt), '{}'::jsonb)
  from (
    select sa.locality_id, count(distinct sa.provider_id) as cnt
    from public.provider_service_areas sa
    join public.provider_profiles pp on pp.id = sa.provider_id
    where pp.base_city_id = p_city_id and pp.status = 'published' and pp.moderation_status = 'active'
    group by sa.locality_id
  ) sa;
$$;

-- ---------------------------------------------------------------------------
-- 5. Registration (atomic create), matching
-- ProviderAuthRepository.registerProfile / RegistrationSubmission exactly.
-- SECURITY DEFINER, not INVOKER: the `authenticated` role has no grant to
-- read auth.users directly (by design -- Supabase locks that table down to
-- auth.uid()/auth.jwt() instead), and this function needs the caller's own
-- confirmed phone number from that table. Running as the definer (table
-- owner) makes that read possible; every write below still explicitly scopes
-- itself to auth.uid() (captured from the *caller's* JWT, which SECURITY
-- DEFINER does not change), so this does not let a caller act as anyone else
-- -- it only lets this one function see the one row it needs.
create or replace function public.register_profile(p_submission jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_phone_confirmed boolean;
  v_city_id text;
  v_locality_id text;
  v_category_ids text[];
  v_service_area_ids text[];
  v_profile_id uuid;
  v_city_status public.city_launch_status;
  v_cat text;
  v_area text;
  v_price jsonb;
  v_caption text;
  v_idx int;
begin
  select phone, phone_confirmed_at is not null into v_phone, v_phone_confirmed
  from auth.users where id = auth.uid();

  if v_phone is null or not v_phone_confirmed then
    raise exception 'not_authenticated: sign in and verify your phone before registering';
  end if;

  v_city_id := p_submission->>'baseCityId';
  v_locality_id := p_submission->>'baseLocalityId';
  select array_agg(x) into v_category_ids from jsonb_array_elements_text(coalesce(p_submission->'categoryIds', '[]'::jsonb)) x;
  select array_agg(x) into v_service_area_ids from jsonb_array_elements_text(coalesce(p_submission->'serviceAreaIds', '[]'::jsonb)) x;

  if coalesce(btrim(p_submission->>'displayName'), '') = '' then
    raise exception 'validation_failed: display name is required';
  end if;
  if v_category_ids is null or array_length(v_category_ids, 1) is null then
    raise exception 'validation_failed: at least one category is required';
  end if;
  if v_service_area_ids is null or array_length(v_service_area_ids, 1) is null then
    raise exception 'validation_failed: at least one service area is required';
  end if;

  select launch_status into v_city_status from public.cities where id = v_city_id;
  if v_city_status is null then
    raise exception 'validation_failed: unknown city %', v_city_id;
  end if;
  if v_city_status <> 'active' then
    raise exception 'location_not_active: % is not an active market yet', v_city_id;
  end if;

  if exists (select 1 from public.provider_profiles where user_id = auth.uid()) then
    raise exception 'conflict: this account already has a profile';
  end if;

  begin
    insert into public.provider_profiles (
      user_id, phone_e164, display_name, base_city_id, base_locality_id,
      description, languages, home_visits, whatsapp_enabled, phone_display_consented, pin_codes
    ) values (
      auth.uid(), v_phone, btrim(p_submission->>'displayName'), v_city_id, v_locality_id,
      nullif(btrim(p_submission->>'description'), ''),
      coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(p_submission->'languages', '[]'::jsonb)) x), '{}'),
      coalesce((p_submission->>'homeVisits')::boolean, true),
      coalesce((p_submission->>'whatsappEnabled')::boolean, false) and coalesce((p_submission->>'phoneDisplayConsented')::boolean, false),
      coalesce((p_submission->>'phoneDisplayConsented')::boolean, false),
      '{}'
    ) returning id into v_profile_id;
  exception when unique_violation then
    raise exception 'conflict: this phone number already owns a profile';
  end;

  foreach v_cat in array v_category_ids loop
    insert into public.provider_categories (provider_id, category_id) values (v_profile_id, v_cat);
  end loop;

  foreach v_area in array v_service_area_ids loop
    insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary)
    values (v_profile_id, v_city_id, v_area, v_area = v_locality_id);
  end loop;

  if p_submission ? 'workingHours' and p_submission->'workingHours' ? 'days' then
    insert into public.provider_working_hours (provider_id, weekday, open_minutes, close_minutes)
    select v_profile_id, (d->>'weekday')::int, (d->>'open')::int, (d->>'close')::int
    from jsonb_array_elements(p_submission->'workingHours'->'days') d;
  end if;

  v_idx := 0;
  for v_caption in select jsonb_array_elements_text(coalesce(p_submission->'photoCaptions', '[]'::jsonb)) loop
    insert into public.provider_photos (provider_id, caption, is_placeholder)
    values (v_profile_id, v_caption, true);
    v_idx := v_idx + 1;
  end loop;

  for v_price in select jsonb_array_elements(coalesce(p_submission->'startingPrices', '[]'::jsonb)) loop
    insert into public.provider_starting_prices (provider_id, category_id, amount_rupees, note)
    values (v_profile_id, v_price->>'categoryId', (v_price->>'amount')::int, v_price->>'note');
  end loop;

  if p_submission ? 'healthcareDetails' and p_submission->'healthcareDetails' is not null then
    insert into public.provider_healthcare_details (
      provider_id, qualification, specialty, clinic_name, clinic_address,
      consultation_hours_note, registration_number, registration_council,
      is_diagnostic_centre, accepts_walk_ins
    ) values (
      v_profile_id,
      p_submission->'healthcareDetails'->>'qualification',
      p_submission->'healthcareDetails'->>'specialty',
      p_submission->'healthcareDetails'->>'clinicName',
      p_submission->'healthcareDetails'->>'clinicAddress',
      p_submission->'healthcareDetails'->>'consultationHoursNote',
      p_submission->'healthcareDetails'->>'registrationNumber',
      p_submission->'healthcareDetails'->>'registrationCouncil',
      coalesce((p_submission->'healthcareDetails'->>'isDiagnosticCentre')::boolean, false),
      coalesce((p_submission->'healthcareDetails'->>'acceptsWalkIns')::boolean, true)
    );
  end if;

  insert into public.consent_records (provider_id, kind, granted, phone_e164)
  values
    (v_profile_id, 'public_profile', true, v_phone),
    (v_profile_id, 'display_phone_number', coalesce((p_submission->>'phoneDisplayConsented')::boolean, false), v_phone),
    (v_profile_id, 'whatsapp_contact', coalesce((p_submission->>'whatsappEnabled')::boolean, false), v_phone);

  return public.provider_profile_json(v_profile_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Admin-only actions.
create or replace function public.record_credential_review(
  p_provider_id uuid, p_credential_id uuid, p_status public.verification_status, p_note text default null
)
returns public.credential_records
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.credential_records;
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may review credentials';
  end if;
  update public.credential_records
    set status = p_status, reviewed_at = now(), reviewed_by = auth.uid()
    where id = p_credential_id and provider_id = p_provider_id
    returning * into v_row;
  if v_row.id is null then
    raise exception 'not_found: credential record not found';
  end if;
  insert into public.verification_records (provider_id, kind, status, method, reviewed_by, reviewed_at, note)
  values (p_provider_id, 'credentials', p_status, 'document_review', auth.uid(), now(), p_note);
  return v_row;
end;
$$;

create or replace function public.set_listing_moderation(
  p_provider_id uuid, p_status public.moderation_status, p_reason text default null
)
returns public.provider_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.provider_profiles;
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may change moderation status';
  end if;
  update public.provider_profiles
    set moderation_status = p_status, suspension_reason = p_reason
    where id = p_provider_id
    returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Engagement summary (owner/admin only; aggregation, not raw event access).
create or replace function public.engagement_summary_for(p_provider_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select user_id into v_owner from public.provider_profiles where id = p_provider_id;
  if v_owner is distinct from auth.uid() and not public.is_admin() then
    raise exception 'not_owner: cannot read another provider''s engagement summary';
  end if;

  return jsonb_build_object(
    'profileViews', coalesce((select count(*) from public.engagement_events where provider_id = p_provider_id and type = 'profile_view'), 0),
    'callButtonTaps', coalesce((select count(*) from public.engagement_events where provider_id = p_provider_id and type = 'call_button_tap'), 0),
    'whatsappButtonTaps', coalesce((select count(*) from public.engagement_events where provider_id = p_provider_id and type = 'whatsapp_button_tap'), 0),
    'shareTaps', coalesce((select count(*) from public.engagement_events where provider_id = p_provider_id and type = 'share_tap'), 0),
    'isSampleData', false,
    'periodStart', (select min(occurred_at) from public.engagement_events where provider_id = p_provider_id),
    'periodEnd', (select max(occurred_at) from public.engagement_events where provider_id = p_provider_id)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Active promotions for a customer's context (public read, curated shape).
create or replace function public.active_promotions(
  p_city_id text, p_locality_id text default null, p_category_id text default null,
  p_placement public.promotion_placement default null
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', pr.id, 'providerId', pr.provider_id, 'placement', pr.placement,
      'startsAt', pr.starts_at, 'endsAt', pr.ends_at, 'priority', pr.priority
    ) order by pr.priority desc), '[]'::jsonb)
  from public.promotions pr
  where pr.state = 'active'
    and now() >= pr.starts_at and now() < pr.ends_at
    and (p_placement is null or pr.placement = p_placement)
    and (pr.city_id is null or pr.city_id = p_city_id)
    and (array_length(pr.locality_ids, 1) is null or p_locality_id is null or p_locality_id = any(pr.locality_ids))
    and (array_length(pr.category_ids, 1) is null or p_category_id is null or p_category_id = any(pr.category_ids));
$$;

-- ---------------------------------------------------------------------------
-- 9. "Who am I" convenience wrappers for ProviderAuthRepository.
-- currentAccount()/currentProfile() restore from a session with no id in
-- hand, so these take no argument and resolve purely from auth.uid().
create or replace function public.my_profile()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.provider_profile_json(pp.id)
  from public.provider_profiles pp
  where pp.user_id = auth.uid();
$$;

-- Synthesizes the ProviderAccount shape (lib/domain/models/account.dart) from
-- auth.users + provider_profiles, since there is no separate accounts table
-- -- see docs/backend-contract.md "Identity model".
create or replace function public.my_account()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', u.id,
    'phoneE164', u.phone,
    'createdAt', u.created_at,
    'profileId', pp.id,
    'phoneVerifiedAt', u.phone_confirmed_at,
    'lastSignedInAt', u.last_sign_in_at,
    'isSuspended', coalesce(pp.moderation_status = 'suspended', false),
    'suspensionReason', pp.suspension_reason
  )
  from auth.users u
  left join public.provider_profiles pp on pp.user_id = u.id
  where u.id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- 10. All published listings in a city (ProviderRepository.publishedInCity,
-- used for counts and the categories tab -- a small, bounded result set in
-- the Mumbai-launch MVP, so no pagination here unlike search_providers).
create or replace function public.providers_published_in_city(p_city_id text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(public.provider_profile_json(pp.id) - 'moderationStatus' order by pp.display_name), '[]'::jsonb)
  from public.provider_profiles pp
  where pp.base_city_id = p_city_id and pp.status = 'published' and pp.moderation_status = 'active';
$$;

-- ---------------------------------------------------------------------------
-- 11. Atomic full update (ProviderRepository.updateProfile). Mirrors
-- register_profile's "replace the child rows in one transaction" shape so a
-- category/service-area swap can never be observed (or rejected by the
-- deferred "must keep at least one" triggers) half-done. Photos are
-- deliberately NOT replaced here -- they are managed incrementally via
-- direct insert/delete against provider_photos + Storage uploads, which
-- matches how a photo picker UI actually works (add one, remove one), not a
-- wholesale array replace.
create or replace function public.update_profile_full(p_profile_id uuid, p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_cat text;
  v_area text;
  v_price jsonb;
begin
  select user_id into v_owner from public.provider_profiles where id = p_profile_id;
  if v_owner is null then
    raise exception 'not_found: profile not found';
  end if;
  if v_owner is distinct from auth.uid() and not public.is_admin() then
    raise exception 'not_owner: cannot edit another provider''s profile';
  end if;

  update public.provider_profiles set
    display_name = coalesce(p_patch->>'displayName', display_name),
    description = case when p_patch ? 'description' then nullif(btrim(p_patch->>'description'), '') else description end,
    languages = case when p_patch ? 'languages' then
        coalesce((select array_agg(x) from jsonb_array_elements_text(p_patch->'languages') x), '{}')
      else languages end,
    home_visits = coalesce((p_patch->>'homeVisits')::boolean, home_visits),
    availability = coalesce((p_patch->>'availability')::public.availability_status, availability),
    whatsapp_enabled = coalesce((p_patch->>'whatsappEnabled')::boolean, whatsapp_enabled),
    phone_display_consented = coalesce((p_patch->>'phoneDisplayConsented')::boolean, phone_display_consented),
    pin_codes = case when p_patch ? 'pinCodes' then
        coalesce((select array_agg(x) from jsonb_array_elements_text(p_patch->'pinCodes') x), '{}')
      else pin_codes end
  where id = p_profile_id;

  if p_patch ? 'categoryIds' then
    delete from public.provider_categories where provider_id = p_profile_id;
    for v_cat in select jsonb_array_elements_text(p_patch->'categoryIds') loop
      insert into public.provider_categories (provider_id, category_id) values (p_profile_id, v_cat);
    end loop;
  end if;

  if p_patch ? 'serviceAreas' then
    delete from public.provider_service_areas where provider_id = p_profile_id;
    insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary, pin_codes)
    select p_profile_id, a->>'cityId', a->>'localityId', coalesce((a->>'isPrimary')::boolean, false),
      coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(a->'pinCodes', '[]'::jsonb)) x), '{}')
    from jsonb_array_elements(p_patch->'serviceAreas') a;
  end if;

  if p_patch ? 'workingHours' then
    delete from public.provider_working_hours where provider_id = p_profile_id;
    if p_patch->'workingHours' is not null and p_patch->'workingHours' ? 'days' then
      insert into public.provider_working_hours (provider_id, weekday, open_minutes, close_minutes)
      select p_profile_id, (d->>'weekday')::int, (d->>'open')::int, (d->>'close')::int
      from jsonb_array_elements(p_patch->'workingHours'->'days') d;
    end if;
  end if;

  if p_patch ? 'startingPrices' then
    delete from public.provider_starting_prices where provider_id = p_profile_id;
    for v_price in select jsonb_array_elements(p_patch->'startingPrices') loop
      insert into public.provider_starting_prices (provider_id, category_id, amount_rupees, note)
      values (p_profile_id, v_price->>'categoryId', (v_price->>'amount')::int, v_price->>'note');
    end loop;
  end if;

  if p_patch ? 'healthcareDetails' then
    delete from public.provider_healthcare_details where provider_id = p_profile_id;
    if p_patch->'healthcareDetails' is not null then
      insert into public.provider_healthcare_details (
        provider_id, qualification, specialty, clinic_name, clinic_address,
        consultation_hours_note, registration_number, registration_council,
        is_diagnostic_centre, accepts_walk_ins
      ) values (
        p_profile_id,
        p_patch->'healthcareDetails'->>'qualification',
        p_patch->'healthcareDetails'->>'specialty',
        p_patch->'healthcareDetails'->>'clinicName',
        p_patch->'healthcareDetails'->>'clinicAddress',
        p_patch->'healthcareDetails'->>'consultationHoursNote',
        p_patch->'healthcareDetails'->>'registrationNumber',
        p_patch->'healthcareDetails'->>'registrationCouncil',
        coalesce((p_patch->'healthcareDetails'->>'isDiagnosticCentre')::boolean, false),
        coalesce((p_patch->'healthcareDetails'->>'acceptsWalkIns')::boolean, true)
      );
    end if;
  end if;

  return public.provider_profile_json(p_profile_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 12. Free-text city and category search (LocationRepository.searchCities,
-- ServiceCatalogRepository.searchCategories). Small, pulled out of
-- search_providers()'s inline logic so a standalone category/city picker can
-- call the same matching rules without duplicating them.
create or replace function public.search_cities(p_text text, p_country_id text default 'in')
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'stateId', c.state_id, 'name', c.name,
      'launchStatus', c.launch_status, 'aliases', to_jsonb(c.aliases), 'isMetro', c.is_metro
    ) order by c.name), '[]'::jsonb)
  from public.cities c
  join public.state_regions sr on sr.id = c.state_id
  where sr.country_id = p_country_id and btrim(p_text) <> '' and (
    c.name ilike '%' || p_text || '%'
    or exists (select 1 from unnest(c.aliases) a where a ilike '%' || p_text || '%')
  );
$$;

create or replace function public.search_categories(p_text text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', sc.id, 'groupId', sc.group_id, 'name', sc.name, 'iconKey', sc.icon_key,
      'sortOrder', sc.sort_order, 'isHealthcare', sc.is_healthcare
    ) order by sc.sort_order), '[]'::jsonb)
  from public.service_categories sc
  where btrim(p_text) <> '' and (
    sc.name ilike '%' || p_text || '%'
    or exists (select 1 from unnest(sc.keywords) k where k ilike '%' || p_text || '%')
  );
$$;
