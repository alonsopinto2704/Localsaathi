-- 0036: phase 087, atomic gallery updates.
--
-- With media_pipeline ON a gallery photo can only be an APPROVED upload of this
-- listing and this account that is not yet attached: the caller names the full
-- derivative path returned by processing, and the row is looked up, not trusted.
-- A path that is rejected, still processing, belongs to another listing, was
-- already used, or was never issued matches nothing. With the flag OFF the
-- pre-081 owner-folder rule is unchanged (staged cutover, see 0030).
--
-- Every write below locks the listing row first (lock_owned_profile), so two
-- concurrent adds queue behind each other and the photo limit is counted
-- against committed rows. Each RPC is one transaction: a replacement that
-- fails leaves the previous gallery exactly as it was.
--
-- Order is uploaded_at ascending (what the projection already sorts by);
-- set_photo_order rewrites it. A real position column would need a projection
-- change owned elsewhere -- see tasks/evidence/phase-087.md.

create or replace function public.check_photo_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select count(*) from public.provider_photos where provider_id = new.provider_id)
     >= private.media_setting('max_photos') then
    raise exception 'validation_failed: free listings may publish at most % photos', private.media_setting('max_photos');
  end if;
  return new;
end;
$$;

-- Locks and returns the caller's unattached, approved upload for this path.
create function private.take_approved_upload(p_profile_id uuid, p_full_path text)
returns private.media_uploads
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_up private.media_uploads;
begin
  select * into v_up from private.media_uploads
    where profile_id = p_profile_id and user_id = auth.uid() and full_path = p_full_path
      and status = 'approved' and not attached
    for update;
  if not found then
    raise exception 'validation_failed: photo is not an approved upload for this listing';
  end if;
  return v_up;
end;
$$;

create or replace function public.add_provider_photo(p_profile_id uuid, p_storage_path text, p_caption text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_up private.media_uploads;
begin
  perform private.require_flag('media_intake');
  perform private.lock_owned_profile(p_profile_id, null);
  if char_length(coalesce(p_caption, '')) > 140 then
    raise exception 'validation_failed: caption is limited to 140 characters';
  end if;
  if public.flag_enabled('media_pipeline') then
    v_up := private.take_approved_upload(p_profile_id, p_storage_path);
    update private.media_uploads set attached = true, updated_at = now() where id = v_up.id;
  elsif p_storage_path is null or p_storage_path !~ ('^' || p_profile_id::text || '/[A-Za-z0-9._-]{1,100}$') then
    raise exception 'validation_failed: photos must be uploaded to this listing''s own folder';
  end if;
  -- clock_timestamp, not now(): the order key must differ even inside one transaction.
  insert into public.provider_photos (provider_id, caption, storage_path, is_placeholder, uploaded_at)
  values (p_profile_id, coalesce(p_caption, ''), p_storage_path, false, clock_timestamp());
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
  v_photo public.provider_photos;
begin
  select * into v_photo from public.provider_photos where id = p_photo_id;
  if not found then
    raise exception 'not_found: photo not found';
  end if;
  perform private.require_flag('media_intake');
  perform private.lock_owned_profile(v_photo.provider_id, null);
  delete from public.provider_photos where id = p_photo_id;
  -- The blobs become orphans (0034) and are removed through the Storage API.
  update private.media_uploads set status = 'retired', updated_at = now()
    where profile_id = v_photo.provider_id and full_path = v_photo.storage_path and status = 'approved';
  update public.provider_profiles set updated_at = now() where id = v_photo.provider_id;
  return public.provider_profile_json(v_photo.provider_id);
end;
$$;

-- Swap one photo for another approved upload in place (same position).
create function public.replace_provider_photo(p_photo_id uuid, p_storage_path text, p_caption text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_photo public.provider_photos;
  v_up private.media_uploads;
begin
  perform private.require_flag('media_intake');
  perform private.require_flag('media_pipeline');
  select * into v_photo from public.provider_photos where id = p_photo_id;
  if not found then
    raise exception 'not_found: photo not found';
  end if;
  perform private.lock_owned_profile(v_photo.provider_id, null);
  select * into v_photo from public.provider_photos where id = p_photo_id;   -- re-read under the lock
  if not found then
    raise exception 'not_found: photo not found';
  end if;
  if p_caption is not null and char_length(p_caption) > 140 then
    raise exception 'validation_failed: caption is limited to 140 characters';
  end if;
  v_up := private.take_approved_upload(v_photo.provider_id, p_storage_path);
  update public.provider_photos set storage_path = p_storage_path, caption = coalesce(p_caption, caption)
    where id = p_photo_id;
  update private.media_uploads set attached = true, updated_at = now() where id = v_up.id;
  update private.media_uploads set status = 'retired', updated_at = now()
    where profile_id = v_photo.provider_id and full_path = v_photo.storage_path and status = 'approved';
  update public.provider_profiles set updated_at = now() where id = v_photo.provider_id;
  return public.provider_profile_json(v_photo.provider_id);
end;
$$;

-- Reorder: the list must be exactly the current photo ids, each once.
create function public.set_photo_order(p_profile_id uuid, p_photo_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base timestamptz;
begin
  perform private.require_flag('media_intake');
  perform private.lock_owned_profile(p_profile_id, null);
  if p_photo_ids is null
     or (select array_agg(id order by id) from public.provider_photos where provider_id = p_profile_id)
        is distinct from (select array_agg(x order by x) from unnest(p_photo_ids) x) then
    raise exception 'validation_failed: the order must list each of your photos exactly once';
  end if;
  select min(uploaded_at) into v_base from public.provider_photos where provider_id = p_profile_id;
  update public.provider_photos p set uploaded_at = v_base + (o.i - 1) * interval '1 millisecond'
    from unnest(p_photo_ids) with ordinality as o(id, i)
    where p.id = o.id and p.provider_id = p_profile_id;
  update public.provider_profiles set updated_at = now() where id = p_profile_id;
  return public.provider_profile_json(p_profile_id);
end;
$$;

revoke execute on function private.take_approved_upload(uuid, text), public.replace_provider_photo(uuid, text, text),
  public.set_photo_order(uuid, uuid[]) from public, anon, authenticated;
grant execute on function public.replace_provider_photo(uuid, text, text), public.set_photo_order(uuid, uuid[]) to authenticated;
