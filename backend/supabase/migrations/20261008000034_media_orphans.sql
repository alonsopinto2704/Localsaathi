-- 0034: phase 085, interrupted uploads and orphans.
--
-- Deleting a database row never removes a blob, and removing a storage.objects
-- row directly would orphan the blob in the object store. So cleanup is two
-- parts: SQL decides what is safe to remove (here); the media-gc Edge Function
-- removes it through the Storage API and re-asks right before each delete.
--
-- Rules (private.media_orphan_reason, the single predicate for list + re-check):
--   * only objects shaped <uuid>/<file> are ever considered; anything else is
--     never deleted;
--   * media-quarantine: an object is removable once its upload finished (any
--     terminal state) and the short original window has passed, once an
--     unfinished upload is expired plus a grace period, or when no upload row
--     exists and the object is older than the grace period. issued/processing
--     uploads inside their window are never touched;
--   * provider-photos: removable only if older than the grace period AND not
--     referenced by a photo row OF THE SAME LISTING (the folder owner), AND not
--     the derivative of a processing/approved upload. A row of another listing
--     naming the path protects nothing;
--   * pause: media_cleanup flag off, or one sweep would delete more than half
--     the objects (and more than 20): reference data looks wrong, so stop and
--     ask a human (p_accept_anomaly overrides after review).
-- Abandoned work is retired here too, so its derivatives become orphans.

create function private.media_orphan_reason(p_bucket text, p_name text, p_created timestamptz)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_grace interval := make_interval(mins => private.media_setting('orphan_grace_minutes'));
  v_keep interval := make_interval(mins => private.media_setting('original_retention_minutes'));
  v_up private.media_uploads;
  v_profile uuid;
begin
  if p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9._-]{1,100}$' then
    return null;
  end if;
  v_profile := split_part(p_name, '/', 1)::uuid;
  if p_bucket = 'media-quarantine' then
    select * into v_up from private.media_uploads where bucket_id = p_bucket and object_path = p_name;
    if not found then
      return case when p_created < now() - v_grace then 'no_upload_row' end;
    end if;
    if v_up.status in ('issued', 'processing') then
      return case when v_up.status = 'issued' and v_up.expires_at + v_grace < now() then 'abandoned' end;
    end if;
    return case when coalesce(v_up.processed_at, v_up.updated_at) < now() - v_keep then 'original_window_over' end;
  elsif p_bucket = 'provider-photos' then
    if p_created >= now() - v_grace then
      return null;
    end if;
    if exists (select 1 from public.provider_photos where provider_id = v_profile and storage_path = p_name)
       or exists (select 1 from private.media_uploads
                  where profile_id = v_profile and status in ('processing', 'approved')
                    and p_name in (full_path, thumb_path))
       or exists (select 1 from private.media_uploads
                  where profile_id = v_profile and status = 'processing'
                    and p_name like profile_id::text || '/' || id::text || '-%') then
      return null;
    end if;
    return 'unreferenced';
  end if;
  return null;
end;
$$;

-- Marks never-finished uploads and approved-but-never-attached photos as over,
-- so the orphan rules above can take their blobs. Safe to run repeatedly.
create function public.expire_media_uploads()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expired int;
  v_failed int;
  v_unattached int;
begin
  update private.media_uploads u set status = 'expired', failure_code = 'expired', updated_at = now()
    where status = 'issued' and expires_at + case
        when exists (select 1 from storage.objects o where o.bucket_id = u.bucket_id and o.name = u.object_path)
        then interval '24 hours' else interval '0' end < now();
  get diagnostics v_expired = row_count;
  -- A run that died repeatedly: stop re-offering it.
  update private.media_uploads set status = 'rejected', failure_code = 'processing_failed', processed_at = now(), updated_at = now()
    where status = 'processing' and attempts >= private.media_setting('max_attempts')
      and updated_at < now() - make_interval(mins => private.media_setting('processing_timeout_minutes'));
  get diagnostics v_failed = row_count;
  update private.media_uploads set status = 'retired', updated_at = now()
    where status = 'approved' and not attached and processed_at < now() - interval '24 hours';
  get diagnostics v_unattached = row_count;
  return jsonb_build_object('expired', v_expired, 'failed', v_failed, 'unattachedRetired', v_unattached);
end;
$$;

create function public.list_media_orphans(p_limit int default 100, p_accept_anomaly boolean default false)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_total int;
  v_cand int;
  v_items jsonb;
begin
  if not public.flag_enabled('media_cleanup') then
    return jsonb_build_object('paused', 'media_cleanup_off', 'items', '[]'::jsonb);
  end if;
  with scan as materialized (
    select o.bucket_id as b, o.name as n, private.media_orphan_reason(o.bucket_id, o.name, o.created_at) as r
    from storage.objects o where o.bucket_id in ('media-quarantine', 'provider-photos')),
  picked as (
    select b, n, r from scan where r is not null order by n limit least(greatest(p_limit, 1), 500))
  select (select count(*) from scan), (select count(r) from scan),
         coalesce((select jsonb_agg(jsonb_build_object('bucket', b, 'name', n, 'reason', r)) from picked), '[]'::jsonb)
    into v_total, v_cand, v_items;
  if v_cand > 20 and v_cand * 2 > v_total and not p_accept_anomaly then
    return jsonb_build_object('paused', 'anomaly', 'items', '[]'::jsonb);
  end if;
  return jsonb_build_object('paused', null, 'items', v_items);
end;
$$;

-- The last check before a delete: still an orphan, flag still on.
create function public.media_object_deletable(p_bucket text, p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.flag_enabled('media_cleanup') and coalesce((
    select private.media_orphan_reason(o.bucket_id, o.name, o.created_at) is not null
    from storage.objects o where o.bucket_id = p_bucket and o.name = p_name), false);
$$;

revoke execute on function private.media_orphan_reason(text, text, timestamptz), public.expire_media_uploads(),
  public.list_media_orphans(int, boolean), public.media_object_deletable(text, text) from public, anon, authenticated;
grant execute on function public.expire_media_uploads(), public.list_media_orphans(int, boolean),
  public.media_object_deletable(text, text) to service_role;
