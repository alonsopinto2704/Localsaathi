-- Follow-ups from the 2026-10-07 external audits of phases 001-040.
--
--  1. 017/028: server-side feature flags (designed in phase-017, never built).
--  2. 022/013: public photos never reveal the owner's auth user id. New
--     provider-photos objects live under <profile_id>/ (public already);
--     legacy <user_id>/ paths are withheld from the public projection.
--  3. 027: an edit can no longer leave a published listing without a
--     launch-approved category or a service area.
--  4. 029/030: payload type errors and FK/NOT NULL failures become
--     validation_failed; update_profile_full bumps revision exactly once.
--  5. 025: credential evidence must sit in the owner's own folder.
--  6. 035: storage cleanup queues exact object paths (no blanket prefix that
--     could later sweep a re-registered provider's new files).
--  7. 036: phone redaction catches formatted numbers; admin writes to reports
--     and promotions are audited.
--  8. 033: per-listing report caps are split by caller kind, engagement has a
--     per-listing ceiling for every caller, and report de-duplication survives
--     the daily source-hash rotation.
--  9. 023: remaining invoker helpers get a pinned search_path.
-- 10. 032: consent wording default is one value everywhere.

-- ---------------------------------------------------------------------------
-- 1. Feature flags. Missing row = off. Only set_feature_flag writes, audited.
create table public.feature_flags (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{1,40}$'),
  enabled boolean not null default false,
  reason text,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
alter table public.feature_flags enable row level security;
revoke all on public.feature_flags from public, anon, authenticated;

-- Production defaults (phase-017 flag matrix). Core paths stay on.
insert into public.feature_flags (key, enabled, reason) values
  ('media_intake', false, 'off until server-side media validation (081-084)'),
  ('credential_intake', false, 'off until credential review workflow (088-089)'),
  ('healthcare_listings', false, 'healthcare categories also not approved for launch'),
  ('sponsored_placement', false, 'off until commercial decision (256)'),
  ('precise_location', false, 'off until precise-location consent (091)'),
  ('provider_signup', true, 'core'),
  ('contact_reveal', true, 'core');

-- Policies and invoker triggers run as the caller, so API roles must be able
-- to execute this (phase-017 section 3). It reveals one boolean per key.
create function public.flag_enabled(p_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select enabled from public.feature_flags where key = p_key), false);
$$;

create function public.get_client_flags()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(key, enabled), '{}'::jsonb) from public.feature_flags;
$$;

create function public.set_feature_flag(p_key text, p_enabled boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may change feature flags';
  end if;
  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 300 then
    raise exception 'validation_failed: a reason (3-300 characters) is required';
  end if;
  insert into public.feature_flags (key, enabled, reason, updated_by, updated_at)
  values (p_key, p_enabled, p_reason, auth.uid(), now())
  on conflict (key) do update set enabled = excluded.enabled, reason = excluded.reason,
    updated_by = excluded.updated_by, updated_at = excluded.updated_at;
  perform private.write_audit('feature_flag_set', 'feature_flag', p_key, p_reason,
    jsonb_build_object('enabled', p_enabled));
end;
$$;

-- Raises feature_disabled for an end user when a flag is off. Service role and
-- migrations (no auth.uid()) and admins are not blocked.
create function private.require_flag(p_key text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null and not public.flag_enabled(p_key) and not public.is_admin() then
    raise exception 'feature_disabled: % is turned off', p_key;
  end if;
end;
$$;

revoke execute on function public.flag_enabled(text), public.get_client_flags(),
  public.set_feature_flag(text, boolean, text), private.require_flag(text) from public;
grant execute on function public.flag_enabled(text), public.get_client_flags() to anon, authenticated;
grant execute on function public.set_feature_flag(text, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Photo storage keyed by profile id; the public projection withholds any
-- path that is not (legacy rows were keyed by the owner's auth user id).
drop policy "owner uploads own provider photos" on storage.objects;
drop policy "owner replaces own provider photos" on storage.objects;
drop policy "owner deletes own provider photos" on storage.objects;
create policy "owner uploads own provider photos" on storage.objects for insert
  with check (bucket_id = 'provider-photos' and exists (
    select 1 from public.provider_profiles pp
    where pp.id::text = (storage.foldername(name))[1] and pp.user_id = auth.uid()));
create policy "owner replaces own provider photos" on storage.objects for update
  using (bucket_id = 'provider-photos' and exists (
    select 1 from public.provider_profiles pp
    where pp.id::text = (storage.foldername(name))[1] and pp.user_id = auth.uid()));
create policy "owner deletes own provider photos" on storage.objects for delete
  using (bucket_id = 'provider-photos' and exists (
    select 1 from public.provider_profiles pp
    where pp.id::text = (storage.foldername(name))[1] and pp.user_id = auth.uid()));

create or replace function public.add_provider_photo(p_profile_id uuid, p_storage_path text, p_caption text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_flag('media_intake');
  perform private.lock_owned_profile(p_profile_id, null);
  if p_storage_path is null or p_storage_path !~ ('^' || p_profile_id::text || '/[A-Za-z0-9._-]{1,100}$') then
    raise exception 'validation_failed: photos must be uploaded to this listing''s own folder';
  end if;
  if char_length(coalesce(p_caption, '')) > 140 then
    raise exception 'validation_failed: caption is limited to 140 characters';
  end if;
  insert into public.provider_photos (provider_id, caption, storage_path, is_placeholder)
  values (p_profile_id, coalesce(p_caption, ''), p_storage_path, false);
  update public.provider_profiles set updated_at = now() where id = p_profile_id;
  return public.provider_profile_json(p_profile_id);
end;
$$;

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
    'verification', coalesce((
      select jsonb_object_agg(v.kind, v.status) from (
        select distinct on (kind) kind, status from public.verification_records
        where provider_id = pp.id order by kind, created_at desc) v
      where v.status = 'approved'), '{}'::jsonb),
    'pinCodes', to_jsonb(pp.pin_codes),
    'mapLocation', case when pp.map_lat is null then null
                        else jsonb_build_object('lat', round(pp.map_lat::numeric, 2), 'lng', round(pp.map_lng::numeric, 2)) end
  )
  from public.provider_profiles pp
  where pp.id = p_id;
$$;
revoke execute on function public.public_profile_json(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3 + 4. Owner writes: typed payloads, clean error codes, one revision bump,
-- and published listings stay publishable after an edit.
alter function public.update_profile_full(uuid, jsonb) rename to update_profile_full_impl;
alter function public.update_profile_full_impl(uuid, jsonb) set schema private;
revoke execute on function private.update_profile_full_impl(uuid, jsonb) from public, anon, authenticated;
alter function public.register_profile(jsonb) rename to register_profile_impl;
alter function public.register_profile_impl(jsonb) set schema private;
revoke execute on function private.register_profile_impl(jsonb) from public, anon, authenticated;

-- Shape checks the old validator assumed (it ran jsonb_array_elements on
-- whatever arrived, so a scalar raised a raw 22023).
create function private.validate_payload_shape(p jsonb)
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

-- A published listing must stay publishable (same rules as publishing).
create function private.assert_still_publishable(p_profile_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.provider_profiles where id = p_profile_id and status = 'published') then
    if not exists (
      select 1 from public.provider_categories pc
      join public.service_categories sc on sc.id = pc.category_id
      where pc.provider_id = p_profile_id and sc.is_approved_for_launch) then
      raise exception 'validation_failed: a published listing needs at least one category open for listings';
    end if;
    if not exists (select 1 from public.provider_service_areas where provider_id = p_profile_id) then
      raise exception 'validation_failed: a published listing needs at least one service area';
    end if;
  end if;
end;
$$;

-- One RPC call = one revision bump. The mutation trigger bumps on every row
-- update (consent changes add extra updates); this later trigger caps the
-- result at the revision the RPC started from + 1.
create function private.cap_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_base text := current_setting('localsaathi.revision_base', true);
begin
  if v_base is not null and v_base <> '' and split_part(v_base, ':', 1) = new.id::text then
    new.revision := least(new.revision, split_part(v_base, ':', 2)::bigint + 1);
  end if;
  return new;
end;
$$;
create trigger trg_zz_cap_revision
  before update on public.provider_profiles
  for each row execute function private.cap_revision();

create function public.update_profile_full(p_profile_id uuid, p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform private.validate_payload_shape(p_patch);
  perform set_config('localsaathi.revision_base', p_profile_id::text || ':' ||
    coalesce((select revision from public.provider_profiles where id = p_profile_id), 0)::text, true);
  v_result := private.update_profile_full_impl(p_profile_id, p_patch);
  perform set_config('localsaathi.revision_base', '', true);
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

create function public.register_profile(p_submission jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_flag('provider_signup');
  perform private.validate_payload_shape(p_submission);
  return private.register_profile_impl(p_submission);
exception
  when invalid_parameter_value or invalid_text_representation or datatype_mismatch
    or numeric_value_out_of_range or not_null_violation or check_violation then
    raise exception 'validation_failed: a field has the wrong type or value';
  when foreign_key_violation then
    raise exception 'validation_failed: unknown category or locality';
end;
$$;

revoke execute on function public.update_profile_full(uuid, jsonb), public.register_profile(jsonb),
  private.validate_payload_shape(jsonb), private.assert_still_publishable(uuid), private.cap_revision()
from public, anon;
revoke execute on function private.validate_payload_shape(jsonb), private.assert_still_publishable(uuid)
from authenticated;
grant execute on function public.update_profile_full(uuid, jsonb), public.register_profile(jsonb) to authenticated;

-- precise_location gate on the map pin.
create or replace function public.set_map_location(p_profile_id uuid, p_lat double precision, p_lng double precision)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
begin
  if p_lat is not null then
    perform private.require_flag('precise_location');
  end if;
  v_row := private.lock_owned_profile(p_profile_id, null);
  if (p_lat is null) <> (p_lng is null) then
    raise exception 'validation_failed: give both coordinates or neither';
  end if;
  if not private.take_rate_token('consent:' || p_profile_id, 'map', interval '1 hour', 30) then
    raise exception 'rate_limited: too many location changes, try again later';
  end if;
  update public.provider_profiles set map_lat = p_lat, map_lng = p_lng where id = p_profile_id;
  insert into public.consent_records (provider_id, kind, granted, phone_e164, wording_version, withdrawn_at)
  values (p_profile_id, 'show_map_location', p_lat is not null, v_row.phone_e164, 'consent-v1',
          case when p_lat is null then now() end);
end;
$$;

-- 10. One wording default.
alter table public.consent_records alter column wording_version set default 'consent-v1';

-- ---------------------------------------------------------------------------
-- 5. Credential evidence must be the owner's own object; intake is flagged.
create function private.check_credential_claim()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;
  perform private.require_flag('credential_intake');
  select user_id into v_owner from public.provider_profiles where id = new.provider_id;
  if new.evidence_storage_path is not null
     and new.evidence_storage_path !~ ('^' || v_owner::text || '/[A-Za-z0-9._-]{1,100}$') then
    raise exception 'validation_failed: evidence must be uploaded to your own folder';
  end if;
  if char_length(coalesce(new.title, '')) not between 1 and 200
     or char_length(coalesce(new.issuing_body, '')) > 200
     or char_length(coalesce(new.registration_number, '')) > 60 then
    raise exception 'validation_failed: credential fields are too long';
  end if;
  if not private.take_rate_token('credential:claim', auth.uid()::text, interval '1 day', 10) then
    raise exception 'rate_limited: too many credential claims today';
  end if;
  return new;
end;
$$;
create trigger trg_check_credential_claim
  before insert on public.credential_records
  for each row execute function private.check_credential_claim();

-- ---------------------------------------------------------------------------
-- 6. Exact-path cleanup. The queue column keeps its name; it now holds a
-- folder prefix (<id>/) or an exact object path.
alter table private.storage_cleanup_queue drop constraint storage_cleanup_queue_prefix_check;
alter table private.storage_cleanup_queue
  add constraint storage_cleanup_queue_prefix_check
  check (prefix ~ '^[0-9a-f-]{36}/([A-Za-z0-9._-]{1,100})?$');

create function private.queue_object_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_path text := to_jsonb(old)->>(case tg_table_name when 'provider_photos' then 'storage_path' else 'evidence_storage_path' end);
  v_bucket text := case tg_table_name when 'provider_photos' then 'provider-photos' else 'credential-evidence' end;
begin
  if v_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}$' then
    insert into private.storage_cleanup_queue (bucket_id, prefix) values (v_bucket, v_path)
    on conflict do nothing;
  end if;
  return old;
end;
$$;
create trigger trg_queue_photo_cleanup after delete on public.provider_photos
  for each row execute function private.queue_object_cleanup();
create trigger trg_queue_credential_cleanup after delete on public.credential_records
  for each row execute function private.queue_object_cleanup();

-- The listing's own photo folder is unique to it (profile id), so a prefix is
-- safe there. Credential evidence is keyed by user and is cleaned per object
-- (trigger above), never by the user's whole folder.
create or replace function private.on_provider_profile_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.reports
    set provider_snapshot = jsonb_build_object(
      'displayName', old.display_name, 'baseCityId', old.base_city_id, 'deletedAt', now())
    where provider_id = old.id;

  insert into private.storage_cleanup_queue (bucket_id, prefix)
  values ('provider-photos', old.id::text || '/')
  on conflict do nothing;

  perform private.write_audit('listing_deleted', 'provider_profile', old.id::text, null,
    jsonb_build_object('by_owner', auth.uid() is not distinct from old.user_id));
  return old;
end;
$$;

drop function public.mark_storage_cleaned(uuid);
create function public.mark_storage_cleaned(p_user_id uuid, p_profile_id uuid default null)
returns void
language sql
security definer
set search_path = ''
as $$
  update private.storage_cleanup_queue set processed_at = now()
  where processed_at is null
    and (prefix like p_user_id::text || '/%'
         or (p_profile_id is not null and prefix like p_profile_id::text || '/%'));
$$;
revoke execute on function public.mark_storage_cleaned(uuid, uuid), private.queue_object_cleanup(),
  private.check_credential_claim() from public, anon, authenticated;
grant execute on function public.mark_storage_cleaned(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 7. Audit: formatted phone numbers are redacted-or-refused too, and admin
-- writes to reports/promotions leave a trail.
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
  -- E.164 (+ and 10-15 digits) or an Indian mobile ([6-9] + 9 digits, optional 91/0);
  -- a unix epoch (starts with 1) or other ids are not phone-shaped.
  if v_text ~ '\+\d{10,15}' or v_text ~ '(^|[^0-9])(91|0)?[6-9]\d{9}([^0-9]|$)' then
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

create function private.audit_admin_table_write()
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
    tg_table_name || '_' || lower(tg_op), tg_table_name, v_row->>'id', null,
    case tg_table_name
      when 'reports' then jsonb_build_object('status', v_row->>'status')
      else jsonb_build_object('provider_id', v_row->>'provider_id', 'state', v_row->>'state')
    end);
  return coalesce(new, old);
end;
$$;
create trigger trg_audit_reports_update after update on public.reports
  for each row execute function private.audit_admin_table_write();
create trigger trg_audit_promotions_write after insert or update or delete on public.promotions
  for each row execute function private.audit_admin_table_write();
revoke execute on function private.audit_admin_table_write() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. Guest writes.
create function private.request_source_on(p_day date)
returns text
language sql
stable
set search_path = ''
as $$
  with h as (select nullif(current_setting('request.headers', true), '')::jsonb as j),
  ip as (
    select btrim(coalesce(
      nullif(btrim(h.j->>'cf-connecting-ip'), ''),
      nullif(btrim((regexp_split_to_array(coalesce(h.j->>'x-forwarded-for', ''), ','))[
        array_length(regexp_split_to_array(coalesce(h.j->>'x-forwarded-for', ''), ','), 1)]), ''))) as v
    from h
  )
  select case
    when auth.uid() is not null then 'u:' || auth.uid()::text
    when (select v from ip) is not null then 'ip:' || md5((select v from ip) || p_day::text)
  end;
$$;
revoke execute on function private.request_source_on(date) from public, anon, authenticated;

create or replace function public.submit_report(
  p_provider_id uuid, p_reason public.report_reason, p_details text default null, p_reporter_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source text := private.request_source();
  v_prev text := private.request_source_on(current_date - 1);
  v_phone text;
  v_existing uuid;
  v_id uuid;
begin
  if not public.is_publicly_listed(p_provider_id) then
    raise exception 'not_found: listing not found';
  end if;
  if char_length(coalesce(p_details, '')) > 1000 then
    raise exception 'validation_failed: details are limited to 1000 characters';
  end if;
  if nullif(btrim(p_reporter_phone), '') is not null then
    v_phone := private.normalize_e164(p_reporter_phone);
    if v_phone is null then
      raise exception 'validation_failed: reporter phone must be a valid number';
    end if;
  end if;

  -- Same reporter, same listing, within a day: one report, same receipt. The
  -- guest source hash rotates daily, so yesterday's hash is checked too.
  select id into v_existing from public.reports
  where v_source is not null
    and provider_id = p_provider_id and reporter_source in (v_source, v_prev)
    and created_at > now() - interval '24 hours'
  limit 1;
  if v_existing is not null then
    return jsonb_build_object('receiptId', v_existing, 'status', 'submitted');
  end if;

  if v_source is not null and (
       not private.take_rate_token('report:source:h', v_source, interval '1 hour', 5)
       or not private.take_rate_token('report:source:d', v_source, interval '1 day', 20)) then
    raise exception 'rate_limited: too many reports, try again later';
  end if;
  -- Separate per-listing budgets: anonymous floods cannot lock out signed-in reporters.
  if not private.take_rate_token('report:provider:d', p_provider_id::text || ':' ||
       case when auth.uid() is null then 'anon' else 'auth' end, interval '1 day', 50) then
    raise exception 'rate_limited: this listing has many open reports already';
  end if;

  insert into public.reports (provider_id, reason, details, reporter_phone_e164, reporter_source)
  values (p_provider_id, p_reason, nullif(btrim(p_details), ''), v_phone, v_source)
  returning id into v_id;
  return jsonb_build_object('receiptId', v_id, 'status', 'submitted');
end;
$$;

create or replace function public.record_engagement(
  p_provider_id uuid, p_type public.engagement_event_type,
  p_city_id text default null, p_locality_id text default null, p_category_id text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source text := private.request_source();
begin
  if not public.is_publicly_listed(p_provider_id) then
    return;
  end if;
  if v_source is not null and (
       not private.take_rate_token('engagement:' || p_type || ':' || p_provider_id, v_source, interval '1 hour', 10)
       or not private.take_rate_token('engagement:source:h', v_source, interval '1 hour', 300)) then
    return;
  end if;
  -- Every caller, sourced or not, shares one per-listing hourly ceiling, so
  -- rotating sources cannot inflate a provider's numbers without bound.
  if not private.take_rate_token('engagement:listing:' || p_type || ':' || p_provider_id, 'all', interval '1 hour', 600) then
    return;
  end if;
  insert into public.engagement_events (provider_id, type, city_id, locality_id, category_id)
  values (
    p_provider_id, p_type,
    (select id from public.cities where id = p_city_id),
    (select id from public.localities where id = p_locality_id),
    (select id from public.service_categories where id = p_category_id)
  );
end;
$$;

-- Sponsored placement is off unless the flag is on.
alter function public.active_promotions(text, text, text, public.promotion_placement) rename to active_promotions_impl;
alter function public.active_promotions_impl(text, text, text, public.promotion_placement) set schema private;
revoke execute on function private.active_promotions_impl(text, text, text, public.promotion_placement) from public, anon, authenticated;
create function public.active_promotions(
  p_city_id text, p_locality_id text default null, p_category_id text default null,
  p_placement public.promotion_placement default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.flag_enabled('sponsored_placement')
    then private.active_promotions_impl(p_city_id, p_locality_id, p_category_id, p_placement)
    else '[]'::jsonb end;
$$;
revoke execute on function public.active_promotions(text, text, text, public.promotion_placement) from public;
grant execute on function public.active_promotions(text, text, text, public.promotion_placement) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Pin search_path on the remaining invoker helpers.
do $$
declare
  f regprocedure;
begin
  for f in
    select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prokind = 'f'
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('alter function %s set search_path = ''''', f);
  end loop;
end;
$$;
