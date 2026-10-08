-- Setup (not a suite): fixtures for the media phases 081-087. Loaded once with
-- 0000_helpers.sql. Test-only; creates synthetic rows, never real objects.
create schema if not exists tests;

-- One upload row for a listing in the given state, plus the storage.objects
-- rows that state implies (quarantine original; for approved, both public
-- derivatives). Returns the upload id; read paths from private.media_uploads.
create or replace function tests.media_upload(
  p_profile uuid, p_user uuid, p_status text default 'approved', p_original boolean default true
)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
  v_approved boolean := p_status = 'approved';
begin
  insert into private.media_uploads (id, profile_id, user_id, class, bucket_id, object_path, declared_mime, max_bytes,
                                     status, attempts, full_path, thumb_path, full_bytes, thumb_bytes, width, height,
                                     expires_at, processed_at)
  values (v_id, p_profile, p_user, 'portfolio_original', 'media-quarantine', p_profile::text || '/' || v_id::text,
          'image/jpeg', 100000, p_status, case when p_status = 'issued' then 0 else 1 end,
          case when v_approved then p_profile::text || '/' || v_id::text || '-full.webp' end,
          case when v_approved then p_profile::text || '/' || v_id::text || '-thumb.webp' end,
          case when v_approved then 20000 end, case when v_approved then 5000 end,
          case when v_approved then 800 end, case when v_approved then 600 end,
          now() + interval '15 minutes', case when p_status in ('approved', 'rejected') then now() end);
  if p_original then
    insert into storage.objects (bucket_id, name, metadata)
      values ('media-quarantine', p_profile::text || '/' || v_id::text, jsonb_build_object('size', 50000));
  end if;
  if v_approved then
    insert into storage.objects (bucket_id, name, metadata)
      values ('provider-photos', p_profile::text || '/' || v_id::text || '-full.webp', jsonb_build_object('size', 20000)),
             ('provider-photos', p_profile::text || '/' || v_id::text || '-thumb.webp', jsonb_build_object('size', 5000));
  end if;
  return v_id;
end;
$$;
grant usage on schema tests to anon, authenticated;
grant execute on all functions in schema tests to anon, authenticated, service_role;
