-- 0031: phase 082, owner-bound upload authorization.
--
-- The client never names a path. request_media_upload (the caller's own JWT;
-- listing ownership is checked by lock_owned_profile) creates one row that
-- fixes the account, listing, class, bucket, generated object path, MIME and a
-- byte ceiling, and expires. The media-upload-authorize Edge Function then
-- asks Storage for a signed upload URL for exactly that path. Every later step
-- (processing, approval, attachment) takes the upload id and reads the path
-- from this row, so a changed destination has nothing to change.
--
-- The row is also the upload's state machine (083, 085):
--   issued -> processing -> approved -> retired (gallery photo removed/replaced)
--          \-> expired (never uploaded / abandoned)   processing -> rejected
-- Lives in `private`, so it adds no public column to classify.

create table private.media_uploads (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.provider_profiles(id) on delete cascade,
  user_id uuid not null,
  class text not null references private.media_classes(class),
  bucket_id text not null,
  object_path text not null,
  declared_mime text not null,
  max_bytes int not null check (max_bytes > 0),
  status text not null default 'issued'
    check (status in ('issued', 'processing', 'approved', 'rejected', 'expired', 'retired')),
  attempts smallint not null default 0,
  failure_code text check (failure_code is null or failure_code ~ '^[a-z_]{1,40}$'),
  -- Filled by complete_media_upload (0033).
  full_path text,
  thumb_path text,
  full_bytes int,
  thumb_bytes int,
  width int,
  height int,
  attached boolean not null default false,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (bucket_id, object_path)
);
create index media_uploads_profile_status on private.media_uploads (profile_id, status);
revoke all on private.media_uploads from public, anon, authenticated;

create function private.media_setting(p_key text)
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select int_value from private.media_settings where key = p_key;
$$;

create function public.request_media_upload(p_profile_id uuid, p_class text, p_declared_mime text, p_declared_bytes int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.provider_profiles;
  v_class private.media_classes;
  v_id uuid := gen_random_uuid();
  v_expires timestamptz := now() + make_interval(mins => private.media_setting('upload_ttl_minutes'));
begin
  perform private.require_flag('media_intake');
  perform private.require_flag('media_pipeline');
  v_profile := private.lock_owned_profile(p_profile_id, null);
  if v_profile.moderation_status <> 'active' then
    raise exception 'not_owner: this listing cannot accept uploads';
  end if;
  select * into v_class from private.media_classes where class = p_class and status = 'active';
  -- Only the portfolio intake is issued here; credentials move in phase 088.
  if not found or v_class.class <> 'portfolio_original' then
    raise exception 'validation_failed: unknown media class';
  end if;
  if p_declared_mime is null or not (p_declared_mime = any (v_class.allowed_mime)) then
    raise exception 'validation_failed: only JPEG, PNG or WebP images are accepted';
  end if;
  if p_declared_bytes is null or p_declared_bytes not between 1 and v_class.max_bytes then
    raise exception 'validation_failed: file must be between 1 byte and % bytes', v_class.max_bytes;
  end if;
  if not private.take_rate_token('media:upload', auth.uid()::text, interval '1 hour', 30) then
    raise exception 'rate_limited: too many uploads this hour';
  end if;
  if (select count(*) from private.media_uploads
      where profile_id = p_profile_id and status in ('issued', 'processing') and expires_at > now())
     >= private.media_setting('max_open_uploads') then
    raise exception 'rate_limited: finish or wait for your pending uploads first';
  end if;
  insert into private.media_uploads (id, profile_id, user_id, class, bucket_id, object_path, declared_mime, max_bytes, expires_at)
  values (v_id, p_profile_id, auth.uid(), v_class.class, v_class.bucket_id, p_profile_id::text || '/' || v_id::text,
          p_declared_mime, p_declared_bytes, v_expires);
  perform private.write_audit('media_upload_issued', 'provider_profile', p_profile_id::text, null,
    jsonb_build_object('upload_id', v_id, 'class', v_class.class));
  return jsonb_build_object('uploadId', v_id, 'bucket', v_class.bucket_id,
    'path', p_profile_id::text || '/' || v_id::text, 'expiresAt', v_expires, 'maxBytes', p_declared_bytes,
    'mime', p_declared_mime);
end;
$$;

revoke execute on function public.request_media_upload(uuid, text, text, int), private.media_setting(text) from public, anon;
grant execute on function public.request_media_upload(uuid, text, text, int) to authenticated;
revoke execute on function private.media_setting(text) from authenticated;
