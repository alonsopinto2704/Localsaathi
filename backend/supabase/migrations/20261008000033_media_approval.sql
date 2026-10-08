-- 0033: phase 084 (approval gate) and the database half of 086 (byte budgets).
--
-- media-process strips metadata and writes the public derivatives; only then
-- does it call complete_media_upload. This function is the gate between
-- "derivatives exist" and "the upload is approved", and it checks what it can
-- check without decoding images:
--   * the caller reports the scanner found NO metadata in either derivative
--     (p_clean); the scanner itself runs in the Edge Function and is tested in
--     backend/test/media-process.test.mjs;
--   * both derivative objects really exist in the public bucket, under keys
--     generated from THIS upload (<profile>/<upload>-thumb|full.<ext>): a
--     caller-chosen key, another listing's folder or another upload's file
--     cannot be approved;
--   * each derivative is within its byte budget and edge length
--     (private.media_derivatives), so oversize images cannot become "approved".
-- Keys contain the upload id, so a replacement photo is a NEW url and the old
-- revision is never overwritten (cache-safe versioning, phase 086).

create function public.complete_media_upload(
  p_upload_id uuid, p_thumb_path text, p_full_path text, p_thumb_bytes int, p_full_bytes int,
  p_width int, p_height int, p_clean boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_up private.media_uploads;
  v_thumb private.media_derivatives;
  v_full private.media_derivatives;
  v_pat text;
begin
  select * into v_up from private.media_uploads where id = p_upload_id for update;
  if not found then
    raise exception 'not_found: upload not found';
  end if;
  if v_up.status = 'approved' and v_up.full_path = p_full_path then
    return;                                            -- idempotent retry
  end if;
  if v_up.status <> 'processing' then
    raise exception 'conflict: upload is %', v_up.status;
  end if;
  if p_clean is not true then
    raise exception 'validation_failed: derivatives were not verified metadata-free';
  end if;
  select * into v_thumb from private.media_derivatives where kind = 'thumb';
  select * into v_full from private.media_derivatives where kind = 'full';
  v_pat := '^' || v_up.profile_id::text || '/' || v_up.id::text || '-%s\.(webp|jpg|png)$';
  if p_thumb_path is null or p_thumb_path !~ format(v_pat, 'thumb')
     or p_full_path is null or p_full_path !~ format(v_pat, 'full') then
    raise exception 'validation_failed: derivative keys must be generated for this upload';
  end if;
  if p_thumb_bytes is null or p_full_bytes is null or p_thumb_bytes not between 1 and v_thumb.max_bytes
     or p_full_bytes not between 1 and v_full.max_bytes then
    raise exception 'validation_failed: derivative exceeds its byte budget';
  end if;
  if p_width is null or p_height is null or p_width < 1 or p_height < 1 or greatest(p_width, p_height) > v_full.max_edge then
    raise exception 'validation_failed: derivative dimensions exceed the display need';
  end if;
  if (select count(*) from storage.objects where bucket_id = 'provider-photos' and name in (p_thumb_path, p_full_path)) <> 2 then
    raise exception 'conflict: derivative objects are not in storage';
  end if;
  update private.media_uploads
    set status = 'approved', thumb_path = p_thumb_path, full_path = p_full_path, thumb_bytes = p_thumb_bytes,
        full_bytes = p_full_bytes, width = p_width, height = p_height, failure_code = null,
        processed_at = now(), updated_at = now()
    where id = p_upload_id;
  perform private.write_audit('media_upload_approved', 'media_upload', p_upload_id::text, null,
    jsonb_build_object('thumb_bytes', p_thumb_bytes, 'full_bytes', p_full_bytes));
end;
$$;

revoke execute on function public.complete_media_upload(uuid, text, text, int, int, int, int, boolean) from public, anon, authenticated;
grant execute on function public.complete_media_upload(uuid, text, text, int, int, int, int, boolean) to service_role;
