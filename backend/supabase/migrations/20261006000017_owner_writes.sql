-- Phases 025 (no direct table writes), 026 (identity + duplicate payloads),
-- 029 (validated atomic mutations, idempotent registration), 030 (revision
-- preconditions).
--
-- 0013 revoked every client INSERT/UPDATE/DELETE on provider tables. This
-- migration provides the owner-checked RPCs that replace the direct writes the
-- contract used for publish/pause/availability/delete/photos, and makes the
-- two big writers validate the WHOLE payload before touching anything.

-- ---------------------------------------------------------------------------
-- Payload validation shared by register_profile and update_profile_full.
-- Raises validation_failed with a field hint; never partially applies.
create function private.validate_profile_payload(p jsonb, p_city_id text)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_ids text[];
  v_day jsonb;
  v_weekdays int[] := '{}';
  v_price jsonb;
begin
  if p ? 'displayName' and char_length(btrim(coalesce(p->>'displayName', ''))) not between 1 and 80 then
    raise exception 'validation_failed: displayName must be 1-80 characters';
  end if;
  if char_length(coalesce(p->>'description', '')) > 1000 then
    raise exception 'validation_failed: description is limited to 1000 characters';
  end if;
  if p ? 'languages' and (jsonb_typeof(p->'languages') <> 'array' or jsonb_array_length(p->'languages') > 10) then
    raise exception 'validation_failed: at most 10 languages';
  end if;

  if p ? 'categoryIds' then
    if jsonb_typeof(p->'categoryIds') <> 'array' then
      raise exception 'validation_failed: categoryIds must be a list';
    end if;
    select array_agg(distinct x) into v_ids from jsonb_array_elements_text(p->'categoryIds') x;
    if coalesce(array_length(v_ids, 1), 0) not between 1 and 10 then
      raise exception 'validation_failed: choose 1-10 categories';
    end if;
    if exists (select 1 from unnest(v_ids) c where not exists (select 1 from public.service_categories sc where sc.id = c)) then
      raise exception 'validation_failed: unknown category';
    end if;
  end if;

  if p ? 'serviceAreaIds' or p ? 'serviceAreas' then
    select array_agg(distinct x) into v_ids from (
      select jsonb_array_elements_text(p->'serviceAreaIds') x where jsonb_typeof(p->'serviceAreaIds') = 'array'
      union all
      select a->>'localityId' from jsonb_array_elements(p->'serviceAreas') a where jsonb_typeof(p->'serviceAreas') = 'array'
    ) s;
    if coalesce(array_length(v_ids, 1), 0) not between 1 and 20 then
      raise exception 'validation_failed: choose 1-20 service areas';
    end if;
    if exists (select 1 from unnest(v_ids) l
               where not exists (select 1 from public.localities lo where lo.id = l and lo.city_id = p_city_id)) then
      raise exception 'validation_failed: every service area must be a locality in your city';
    end if;
  end if;

  if p ? 'workingHours' and p->'workingHours' is not null and jsonb_typeof(p->'workingHours') <> 'null' then
    if jsonb_typeof(p->'workingHours'->'days') <> 'array' or jsonb_array_length(p->'workingHours'->'days') > 7 then
      raise exception 'validation_failed: workingHours.days must list at most 7 days';
    end if;
    for v_day in select jsonb_array_elements(p->'workingHours'->'days') loop
      if coalesce((v_day->>'weekday')::int, 0) not between 1 and 7 or (v_day->>'weekday')::int = any(v_weekdays) then
        raise exception 'validation_failed: each weekday 1-7 at most once';
      end if;
      v_weekdays := v_weekdays || (v_day->>'weekday')::int;
      if ((v_day->>'open') is null) <> ((v_day->>'close') is null)
         or coalesce((v_day->>'open')::int, 0) not between 0 and 1439
         or coalesce((v_day->>'close')::int, 0) not between 0 and 1439 then
        raise exception 'validation_failed: hours are minutes 0-1439, open and close together';
      end if;
    end loop;
  end if;

  if p ? 'startingPrices' then
    if jsonb_typeof(p->'startingPrices') <> 'array' or jsonb_array_length(p->'startingPrices') > 10 then
      raise exception 'validation_failed: at most 10 starting prices';
    end if;
    for v_price in select jsonb_array_elements(p->'startingPrices') loop
      if coalesce((v_price->>'amount')::int, -1) not between 0 and 1000000
         or char_length(coalesce(v_price->>'note', '')) > 140 then
        raise exception 'validation_failed: a starting price is 0-1000000 rupees with a note up to 140 characters';
      end if;
    end loop;
    if (select count(distinct x->>'categoryId') <> count(*) from jsonb_array_elements(p->'startingPrices') x) then
      raise exception 'validation_failed: one starting price per category';
    end if;
  end if;

  if p ? 'photoCaptions' and (jsonb_typeof(p->'photoCaptions') <> 'array' or jsonb_array_length(p->'photoCaptions') > 5) then
    raise exception 'validation_failed: at most 5 photos';
  end if;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'validation_failed: a field has the wrong type';
end;
$$;

-- ---------------------------------------------------------------------------
-- 029: idempotency for registration (the one write with side effects a blind
-- retry could duplicate or misreport). Keys are per user, kept 24 h (purged
-- by private.purge_expired_records, 0019).
create table private.idempotency_keys (
  user_id uuid not null,
  key text not null check (char_length(key) between 8 and 64),
  request_hash text not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id, key)
);
revoke all on private.idempotency_keys from public, anon, authenticated;

-- ---------------------------------------------------------------------------
create or replace function public.register_profile(p_submission jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_phone text;
  v_city_id text := p_submission->>'baseCityId';
  v_locality_id text := p_submission->>'baseLocalityId';
  v_key text := nullif(p_submission->>'idempotencyKey', '');
  v_hash text := md5((p_submission - 'idempotencyKey')::text);
  v_prior private.idempotency_keys;
  v_profile_id uuid;
  v_city_status public.city_launch_status;
  v_phone_consent boolean := coalesce((p_submission->>'phoneDisplayConsented')::boolean, false);
  v_whatsapp boolean := coalesce((p_submission->>'whatsappEnabled')::boolean, false);
  v_result jsonb;
begin
  select private.normalize_e164(u.phone) into v_phone
  from auth.users u where u.id = v_uid and u.phone_confirmed_at is not null;
  if v_phone is null then
    raise exception 'not_authenticated: sign in and verify your phone before registering';
  end if;

  if v_key is not null then
    select * into v_prior from private.idempotency_keys where user_id = v_uid and key = v_key;
    if found then
      if v_prior.request_hash = v_hash then
        return v_prior.response;
      end if;
      raise exception 'conflict: idempotency key reused with a different registration';
    end if;
  end if;

  select launch_status into v_city_status from public.cities where id = v_city_id;
  if v_city_status is null then
    raise exception 'validation_failed: unknown city';
  end if;
  if v_city_status <> 'active' then
    raise exception 'location_not_active: % is not an active market yet', v_city_id;
  end if;
  if not exists (select 1 from public.localities where id = v_locality_id and city_id = v_city_id) then
    raise exception 'validation_failed: base locality must be in the chosen city';
  end if;
  if not (p_submission ? 'displayName' and p_submission ? 'categoryIds' and p_submission ? 'serviceAreaIds') then
    raise exception 'validation_failed: displayName, categoryIds and serviceAreaIds are required';
  end if;
  perform private.validate_profile_payload(p_submission, v_city_id);

  if exists (select 1 from public.provider_profiles where user_id = v_uid) then
    raise exception 'conflict: this account already has a profile';
  end if;

  begin
    insert into public.provider_profiles (
      user_id, phone_e164, display_name, base_city_id, base_locality_id,
      description, languages, home_visits, whatsapp_enabled, phone_display_consented
    ) values (
      v_uid, v_phone, btrim(p_submission->>'displayName'), v_city_id, v_locality_id,
      nullif(btrim(p_submission->>'description'), ''),
      coalesce((select array_agg(distinct x) from jsonb_array_elements_text(coalesce(p_submission->'languages', '[]')) x), '{}'),
      coalesce((p_submission->>'homeVisits')::boolean, true),
      v_whatsapp and v_phone_consent,
      v_phone_consent
    ) returning id into v_profile_id;
  exception when unique_violation then
    -- Concurrent registration for the same user or number: exactly one wins.
    raise exception 'conflict: this phone number already owns a profile';
  end;

  insert into public.provider_categories (provider_id, category_id)
  select distinct v_profile_id, x from jsonb_array_elements_text(p_submission->'categoryIds') x;

  insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary)
  select v_profile_id, v_city_id, x, x = v_locality_id
  from (select distinct x from jsonb_array_elements_text(p_submission->'serviceAreaIds') x) s;

  if jsonb_typeof(p_submission->'workingHours'->'days') = 'array' then
    insert into public.provider_working_hours (provider_id, weekday, open_minutes, close_minutes)
    select v_profile_id, (d->>'weekday')::int, (d->>'open')::int, (d->>'close')::int
    from jsonb_array_elements(p_submission->'workingHours'->'days') d;
  end if;

  insert into public.provider_photos (provider_id, caption, is_placeholder)
  select v_profile_id, left(c, 140), true
  from jsonb_array_elements_text(coalesce(p_submission->'photoCaptions', '[]')) c;

  insert into public.provider_starting_prices (provider_id, category_id, amount_rupees, note)
  select v_profile_id, x->>'categoryId', (x->>'amount')::int, x->>'note'
  from jsonb_array_elements(coalesce(p_submission->'startingPrices', '[]')) x;

  if jsonb_typeof(p_submission->'healthcareDetails') = 'object' then
    insert into public.provider_healthcare_details (
      provider_id, qualification, specialty, clinic_name, clinic_address,
      consultation_hours_note, registration_number, registration_council,
      is_diagnostic_centre, accepts_walk_ins
    )
    select v_profile_id, left(h->>'qualification', 200), left(h->>'specialty', 200), left(h->>'clinicName', 200),
      left(h->>'clinicAddress', 300), left(h->>'consultationHoursNote', 300), left(h->>'registrationNumber', 60),
      left(h->>'registrationCouncil', 200), coalesce((h->>'isDiagnosticCentre')::boolean, false),
      coalesce((h->>'acceptsWalkIns')::boolean, true)
    from (select p_submission->'healthcareDetails' as h) x;
  end if;

  insert into public.consent_records (provider_id, kind, granted, phone_e164)
  values
    (v_profile_id, 'public_profile', true, v_phone),
    (v_profile_id, 'display_phone_number', v_phone_consent, v_phone),
    (v_profile_id, 'whatsapp_contact', v_whatsapp and v_phone_consent, v_phone);

  -- The auth sync trigger only records phone verification on a later change;
  -- a new registrant's confirmed OTP is recorded here.
  insert into public.verification_records (provider_id, kind, status, method, note)
  values (v_profile_id, 'phone', 'approved', 'otp_sms',
          'Phone control confirmed by one-time code. This says nothing about professional qualifications.');

  v_result := public.provider_profile_json(v_profile_id);
  if v_key is not null then
    insert into private.idempotency_keys (user_id, key, request_hash, response)
    values (v_uid, v_key, v_hash, v_result);
  end if;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Owner check + optimistic revision check, shared by every owner write.
create function private.lock_owned_profile(p_profile_id uuid, p_expected_revision bigint)
returns public.provider_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
begin
  select * into v_row from public.provider_profiles where id = p_profile_id for update;
  if not found then
    raise exception 'not_found: profile not found';
  end if;
  -- Owner only. Admins change listings through the audited moderation RPCs,
  -- never by silently editing a provider's content (insider-misuse control).
  if v_row.user_id is distinct from auth.uid() then
    raise exception 'not_owner: cannot edit another provider''s profile';
  end if;
  if p_expected_revision is not null and p_expected_revision <> v_row.revision then
    raise exception 'conflict: revision_mismatch (you have %, current is %)', p_expected_revision, v_row.revision;
  end if;
  return v_row;
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
  v_row := private.lock_owned_profile(p_profile_id, (p_patch->>'expectedRevision')::bigint);
  perform private.validate_profile_payload(p_patch, v_row.base_city_id);
  if p_patch ? 'serviceAreas' and exists (
       select 1 from jsonb_array_elements(p_patch->'serviceAreas') a
       where coalesce(a->>'cityId', v_row.base_city_id) <> v_row.base_city_id) then
    raise exception 'validation_failed: service areas must be in your base city';
  end if;
  if p_patch ? 'availability' and not (p_patch->>'availability') = any(enum_range(null::public.availability_status)::text[]) then
    raise exception 'validation_failed: unknown availability';
  end if;

  -- Consent-bearing fields: recorded and applied, never silently flipped.
  if p_patch ? 'phoneDisplayConsented'
     and (p_patch->>'phoneDisplayConsented')::boolean is distinct from v_row.phone_display_consented then
    perform private.apply_consent(p_profile_id, 'display_phone_number', (p_patch->>'phoneDisplayConsented')::boolean);
  end if;
  if p_patch ? 'whatsappEnabled'
     and (p_patch->>'whatsappEnabled')::boolean is distinct from
         (select whatsapp_enabled from public.provider_profiles where id = p_profile_id) then
    perform private.apply_consent(p_profile_id, 'whatsapp_contact', (p_patch->>'whatsappEnabled')::boolean);
  end if;

  update public.provider_profiles set
    display_name = coalesce(btrim(p_patch->>'displayName'), display_name),
    description = case when p_patch ? 'description' then nullif(btrim(p_patch->>'description'), '') else description end,
    languages = case when p_patch ? 'languages' then
        coalesce((select array_agg(distinct x) from jsonb_array_elements_text(p_patch->'languages') x), '{}')
      else languages end,
    home_visits = coalesce((p_patch->>'homeVisits')::boolean, home_visits),
    availability = coalesce((p_patch->>'availability')::public.availability_status, availability),
    pin_codes = case when p_patch ? 'pinCodes' then
        coalesce((select array_agg(distinct left(x, 6)) from jsonb_array_elements_text(p_patch->'pinCodes') x), '{}')
      else pin_codes end
  where id = p_profile_id;

  if p_patch ? 'categoryIds' then
    delete from public.provider_categories where provider_id = p_profile_id;
    insert into public.provider_categories (provider_id, category_id)
    select distinct p_profile_id, x from jsonb_array_elements_text(p_patch->'categoryIds') x;
  end if;

  if p_patch ? 'serviceAreas' then
    delete from public.provider_service_areas where provider_id = p_profile_id;
    insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary, pin_codes)
    select distinct on (a->>'localityId') p_profile_id, v_row.base_city_id, a->>'localityId',
      coalesce((a->>'isPrimary')::boolean, false),
      coalesce((select array_agg(distinct left(x, 6)) from jsonb_array_elements_text(coalesce(a->'pinCodes', '[]')) x), '{}')
    from jsonb_array_elements(p_patch->'serviceAreas') a
    order by a->>'localityId';
  end if;

  if p_patch ? 'workingHours' then
    delete from public.provider_working_hours where provider_id = p_profile_id;
    if jsonb_typeof(p_patch->'workingHours'->'days') = 'array' then
      insert into public.provider_working_hours (provider_id, weekday, open_minutes, close_minutes)
      select p_profile_id, (d->>'weekday')::int, (d->>'open')::int, (d->>'close')::int
      from jsonb_array_elements(p_patch->'workingHours'->'days') d;
    end if;
  end if;

  if p_patch ? 'startingPrices' then
    delete from public.provider_starting_prices where provider_id = p_profile_id;
    insert into public.provider_starting_prices (provider_id, category_id, amount_rupees, note)
    select p_profile_id, x->>'categoryId', (x->>'amount')::int, x->>'note'
    from jsonb_array_elements(p_patch->'startingPrices') x;
  end if;

  if p_patch ? 'healthcareDetails' then
    delete from public.provider_healthcare_details where provider_id = p_profile_id;
    if jsonb_typeof(p_patch->'healthcareDetails') = 'object' then
      insert into public.provider_healthcare_details (
        provider_id, qualification, specialty, clinic_name, clinic_address,
        consultation_hours_note, registration_number, registration_council,
        is_diagnostic_centre, accepts_walk_ins
      )
      select p_profile_id, left(h->>'qualification', 200), left(h->>'specialty', 200), left(h->>'clinicName', 200),
        left(h->>'clinicAddress', 300), left(h->>'consultationHoursNote', 300), left(h->>'registrationNumber', 60),
        left(h->>'registrationCouncil', 200), coalesce((h->>'isDiagnosticCentre')::boolean, false),
        coalesce((h->>'acceptsWalkIns')::boolean, true)
      from (select p_patch->'healthcareDetails' as h) x;
    end if;
  end if;

  return public.provider_profile_json(p_profile_id);
exception
  when foreign_key_violation then
    raise exception 'validation_failed: unknown category or locality';
  when invalid_text_representation then
    raise exception 'validation_failed: a field has the wrong type';
end;
$$;

-- Replaces the direct `.update({status})` of the old contract. Publication
-- rules run in the row trigger, so this cannot publish an invalid listing.
create function public.set_listing_status(p_profile_id uuid, p_status public.listing_status, p_expected_revision bigint default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_owned_profile(p_profile_id, p_expected_revision);
  update public.provider_profiles set status = p_status where id = p_profile_id;
  return public.provider_profile_json(p_profile_id);
end;
$$;

create function public.set_availability(p_profile_id uuid, p_availability public.availability_status)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_owned_profile(p_profile_id, null);
  update public.provider_profiles set availability = p_availability where id = p_profile_id;
  return public.provider_profile_json(p_profile_id);
end;
$$;

-- Hard delete of the listing (children cascade; Storage cleanup is queued by
-- the delete trigger in 0019). The auth account remains until delete-account.
create function public.delete_listing(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_owned_profile(p_profile_id, null);
  delete from public.provider_profiles where id = p_profile_id;
end;
$$;

-- Photos: the object must already be in the caller's own folder of the
-- provider-photos bucket. No client-supplied URL is stored; clients build the
-- public URL from storagePath.
create function public.add_provider_photo(p_profile_id uuid, p_storage_path text, p_caption text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
begin
  v_row := private.lock_owned_profile(p_profile_id, null);
  if p_storage_path is null or p_storage_path !~ ('^' || v_row.user_id::text || '/[A-Za-z0-9._-]{1,100}$') then
    raise exception 'validation_failed: photos must be uploaded to your own folder';
  end if;
  if char_length(coalesce(p_caption, '')) > 140 then
    raise exception 'validation_failed: caption is limited to 140 characters';
  end if;
  insert into public.provider_photos (provider_id, caption, storage_path, is_placeholder)
  values (p_profile_id, coalesce(p_caption, ''), p_storage_path, false);
  return public.provider_profile_json(p_profile_id);
end;
$$;

create function public.delete_provider_photo(p_photo_id uuid)
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
  perform private.lock_owned_profile(v_profile_id, null);
  delete from public.provider_photos where id = p_photo_id;
  return public.provider_profile_json(v_profile_id);
end;
$$;

revoke execute on function
  public.set_listing_status(uuid, public.listing_status, bigint),
  public.set_availability(uuid, public.availability_status),
  public.delete_listing(uuid),
  public.add_provider_photo(uuid, text, text),
  public.delete_provider_photo(uuid)
from public, anon;
grant execute on function
  public.set_listing_status(uuid, public.listing_status, bigint),
  public.set_availability(uuid, public.availability_status),
  public.delete_listing(uuid),
  public.add_provider_photo(uuid, text, text),
  public.delete_provider_photo(uuid)
to authenticated;
revoke execute on function private.validate_profile_payload(jsonb, text), private.lock_owned_profile(uuid, bigint)
from public, anon, authenticated;

-- 025: signed-in users still had SELECT on provider_profiles, and the 0009
-- "published and active listings are public" policy let ANY account read the
-- raw row (user_id, exact map pin, phone regardless of consent) of every
-- listing, bypassing public_profile_json. Raw rows are now owner/admin only;
-- everyone discovers through the RPCs. The write policies below have had no
-- grant since 0013; dropping them means a future grant cannot revive direct
-- writes by accident.
drop policy "published and active listings are public" on public.provider_profiles;
drop policy "owner creates own profile" on public.provider_profiles;
drop policy "owner updates own profile" on public.provider_profiles;
drop policy "owner deletes own profile" on public.provider_profiles;
drop policy "owner appends own consent record" on public.consent_records;

-- 0012's owner RPCs: same behaviour, stable error prefix (validation_failed),
-- empty search_path, and the version string bounded.
create or replace function public.set_map_location(p_profile_id uuid, p_lat double precision, p_lng double precision)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
begin
  v_row := private.lock_owned_profile(p_profile_id, null);
  if (p_lat is null) <> (p_lng is null) then
    raise exception 'validation_failed: give both coordinates or neither';
  end if;
  update public.provider_profiles set map_lat = p_lat, map_lng = p_lng where id = p_profile_id;
  insert into public.consent_records (provider_id, kind, granted, phone_e164, withdrawn_at)
  values (p_profile_id, 'show_map_location', p_lat is not null, v_row.phone_e164,
          case when p_lat is null then now() end);
end;
$$;

create or replace function public.record_terms_acceptance(p_profile_id uuid, p_version text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
begin
  v_row := private.lock_owned_profile(p_profile_id, null);
  if char_length(btrim(coalesce(p_version, ''))) not between 1 and 40 then
    raise exception 'validation_failed: terms version required (up to 40 characters)';
  end if;
  insert into public.consent_records (provider_id, kind, granted, phone_e164, wording_version)
  values (p_profile_id, 'terms_accepted', true, v_row.phone_e164, btrim(p_version));
end;
$$;
