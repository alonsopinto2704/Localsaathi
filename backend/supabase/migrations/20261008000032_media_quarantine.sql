-- 0032: phase 083, quarantine and content validation (database side).
--
-- Pending files live in the private media-quarantine bucket and are never
-- served. The Edge Function media-process does the actual content validation
-- (magic bytes, structure, dimensions, size) on the bytes themselves; the
-- database decides WHETHER it may start and records the outcome:
--   * the caller must be the account the upload was issued to;
--   * the authorisation must be unexpired AND the object must have been written
--     before it expired (the upload token's own lifetime is a platform detail);
--   * the object must exist at the stored path (a different path has nothing
--     to match) and be within the byte ceiling;
--   * attempts are bounded; a crashed run is reclaimed after a timeout.
-- Terminal refusals are RETURNED as {status, code} (a raise would roll back the
-- state change); only "not found / not yours / not ready / wrong state" raise.
-- A rejected upload records a short code only, never a message or file detail.

create function public.begin_media_processing(p_upload_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_up private.media_uploads;
  v_obj storage.objects;
  v_size bigint;
begin
  select * into v_up from private.media_uploads where id = p_upload_id for update;
  if not found or v_up.user_id is distinct from p_user_id then
    raise exception 'not_found: upload not found';  -- same answer for "not yours"
  end if;
  if v_up.status = 'processing'
     and v_up.updated_at < now() - make_interval(mins => private.media_setting('processing_timeout_minutes')) then
    v_up.status := 'issued';                         -- the previous run died; reclaim it
  end if;
  if v_up.status = 'approved' then
    return jsonb_build_object('uploadId', v_up.id, 'status', 'approved');   -- idempotent retry
  end if;
  if v_up.status <> 'issued' then
    raise exception 'conflict: upload is %', v_up.status;
  end if;
  select * into v_obj from storage.objects where bucket_id = v_up.bucket_id and name = v_up.object_path;
  if not found then
    if v_up.expires_at < now() then
      update private.media_uploads set status = 'expired', failure_code = 'expired', updated_at = now() where id = v_up.id;
      return jsonb_build_object('status', 'expired', 'code', 'expired');
    end if;
    raise exception 'conflict: nothing uploaded yet';
  end if;
  if v_obj.created_at > v_up.expires_at then
    update private.media_uploads set status = 'rejected', failure_code = 'expired', processed_at = now(), updated_at = now() where id = v_up.id;
    return jsonb_build_object('status', 'rejected', 'code', 'expired');   -- returned, not raised: a raise would roll the update back
  end if;
  if v_up.attempts >= private.media_setting('max_attempts') then
    update private.media_uploads set status = 'rejected', failure_code = 'too_many_attempts', processed_at = now(), updated_at = now() where id = v_up.id;
    return jsonb_build_object('status', 'rejected', 'code', 'too_many_attempts');
  end if;
  v_size := coalesce((v_obj.metadata->>'size')::bigint, 0);
  if v_size < 1 or v_size > v_up.max_bytes then
    update private.media_uploads set status = 'rejected', failure_code = 'too_large', processed_at = now(), updated_at = now() where id = v_up.id;
    return jsonb_build_object('status', 'rejected', 'code', 'too_large');
  end if;
  update private.media_uploads set status = 'processing', attempts = attempts + 1, updated_at = now() where id = v_up.id;
  return jsonb_build_object('uploadId', v_up.id, 'status', 'processing', 'profileId', v_up.profile_id,
    'bucket', v_up.bucket_id, 'path', v_up.object_path, 'mime', v_up.declared_mime,
    'maxBytes', v_up.max_bytes, 'attempt', v_up.attempts + 1);
end;
$$;

-- Records that content validation or processing failed. Idempotent on a
-- terminal row; `retry` leaves the upload re-triable (transient failure).
create function public.reject_media_upload(p_upload_id uuid, p_code text, p_retry boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_code is null or p_code !~ '^[a-z_]{1,40}$' then
    raise exception 'validation_failed: failure code must be a short lowercase code';
  end if;
  update private.media_uploads
    set status = case when p_retry and attempts < private.media_setting('max_attempts') then 'issued' else 'rejected' end,
        failure_code = p_code, processed_at = case when p_retry then null else now() end, updated_at = now()
    where id = p_upload_id and status = 'processing';
  if found then
    perform private.write_audit('media_upload_failed', 'media_upload', p_upload_id::text, null,
      jsonb_build_object('code', p_code, 'retry', p_retry));
  end if;
end;
$$;

-- The owner's view of their own upload: a clear processing state.
create function public.get_media_upload(p_upload_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object('uploadId', id, 'status', status, 'failureCode', failure_code,
                              'expiresAt', expires_at, 'attached', attached)
    from private.media_uploads where id = p_upload_id and user_id = auth.uid()), 'null'::jsonb);
$$;

revoke execute on function public.begin_media_processing(uuid, uuid), public.reject_media_upload(uuid, text, boolean),
  public.get_media_upload(uuid) from public, anon, authenticated;
grant execute on function public.begin_media_processing(uuid, uuid), public.reject_media_upload(uuid, text, boolean) to service_role;
grant execute on function public.get_media_upload(uuid) to authenticated;
