-- Phase 040 red-team findings (tasks/evidence/phase-040-redteam.md).
--
-- F2: record_consent / record_terms_acceptance were unthrottled: one account
--     appended 600+ consent rows in a loop. 60 changes per hour per account is
--     far above any real use.
-- F3: adding/removing a photo changed public content without bumping the
--     profile revision, so an edit form holding the old revision would not
--     detect it. Touching the row runs the trigger, which increments revision.

create or replace function public.record_consent(
  p_profile_id uuid, p_kind public.consent_kind, p_granted boolean, p_wording_version text default 'consent-v1'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.provider_profiles where id = p_profile_id and user_id = auth.uid()) then
    raise exception 'not_owner: cannot record consent for another provider';
  end if;
  if char_length(coalesce(p_wording_version, '')) > 40 then
    raise exception 'validation_failed: wording version too long';
  end if;
  if not private.take_rate_token('consent:user:h', auth.uid()::text, interval '1 hour', 60) then
    raise exception 'rate_limited: too many consent changes, try again later';
  end if;
  perform private.apply_consent(p_profile_id, p_kind, p_granted, p_wording_version);
  return public.provider_profile_json(p_profile_id);
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
  if not private.take_rate_token('consent:user:h', auth.uid()::text, interval '1 hour', 60) then
    raise exception 'rate_limited: too many consent changes, try again later';
  end if;
  insert into public.consent_records (provider_id, kind, granted, phone_e164, wording_version)
  values (p_profile_id, 'terms_accepted', true, v_row.phone_e164, btrim(p_version));
end;
$$;

create or replace function public.add_provider_photo(p_profile_id uuid, p_storage_path text, p_caption text default '')
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
  update public.provider_profiles set updated_at = now() where id = p_profile_id;
  return public.provider_profile_json(p_profile_id);
end;
$$;

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
  perform private.lock_owned_profile(v_profile_id, null);
  delete from public.provider_photos where id = p_photo_id;
  update public.provider_profiles set updated_at = now() where id = v_profile_id;
  return public.provider_profile_json(v_profile_id);
end;
$$;
