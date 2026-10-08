-- Phase 083 (migration 0032): quarantine and processing gate. Phones +91900032xxxx.
-- Content validation itself (magic bytes, structure, dimensions) is in the Edge
-- Function and tested in backend/test/media-process.test.mjs.
begin;
select plan(17);
select tests.ensure_reference_data();
select tests.set_flag('media_intake', true);
select tests.set_flag('media_pipeline', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('owner', tests.create_phone_user('+919000320001')::text),
  ('other', tests.create_phone_user('+919000320002')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000320001', 'Quarantine Listing')::text;

-- Five uploads issued the real way (u1..u5).
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
insert into fx select 'u' || g, (public.request_media_upload((select value::uuid from fx where key = 'a'),
  'portfolio_original', 'image/jpeg', 100000)->>'uploadId') from generate_series(1, 5) g;
reset role;
create function pg_temp.put(p_key text, p_size bigint default 50000) returns void language sql as $$
  insert into storage.objects (bucket_id, name, metadata)
  select bucket_id, object_path, jsonb_build_object('size', p_size) from private.media_uploads
  where id = (select value::uuid from fx where key = p_key);
$$;

set local role service_role;
select throws_like(format($sql$ select public.begin_media_processing(%L::uuid, %L::uuid) $sql$,
  (select value from fx where key = 'u1'), (select value from fx where key = 'owner')),
  'conflict: nothing uploaded%', 'nothing is processed before an object exists');
reset role;

select pg_temp.put('u1');
set local role service_role;
insert into fx select 'p1', public.begin_media_processing((select value::uuid from fx where key = 'u1'), (select value::uuid from fx where key = 'owner'))::text;
select is((select value::jsonb->>'status' from fx where key = 'p1'), 'processing', 'an uploaded object moves to processing');
select is((select value::jsonb->>'path' from fx where key = 'p1') like (select value from fx where key = 'a') || '/%', true,
  'the path handed to the processor comes from the stored row');
select throws_like(format($sql$ select public.begin_media_processing(%L::uuid, %L::uuid) $sql$,
  (select value from fx where key = 'u1'), (select value from fx where key = 'other')),
  'not_found:%', 'another account cannot start (or probe) someone else''s upload');
select throws_like(format($sql$ select public.begin_media_processing(%L::uuid, %L::uuid) $sql$,
  (select value from fx where key = 'u1'), (select value from fx where key = 'owner')),
  'conflict: upload is processing%', 'a second concurrent run is refused');
reset role;

-- A crashed run is reclaimed after the timeout.
update private.media_uploads set updated_at = now() - interval '11 minutes' where id = (select value::uuid from fx where key = 'u1');
set local role service_role;
select is(public.begin_media_processing((select value::uuid from fx where key = 'u1'), (select value::uuid from fx where key = 'owner'))->>'attempt', '2',
  'a stale processing run is reclaimed; attempts are counted');
-- Bounded retries: reject-with-retry twice more, then no further attempt.
select public.reject_media_upload((select value::uuid from fx where key = 'u1'), 'processing_failed', true);
select public.begin_media_processing((select value::uuid from fx where key = 'u1'), (select value::uuid from fx where key = 'owner'));
select public.reject_media_upload((select value::uuid from fx where key = 'u1'), 'processing_failed', true);
select throws_like(format($sql$ select public.begin_media_processing(%L::uuid, %L::uuid) $sql$,
  (select value from fx where key = 'u1'), (select value from fx where key = 'owner')),
  'conflict:%', 'after the attempt limit the upload is not processed again');
reset role;
select is((select status || ':' || failure_code from private.media_uploads where id = (select value::uuid from fx where key = 'u1')),
  'rejected:processing_failed', 'it ends rejected with a short code once retries are exhausted');

-- Oversize object (size beyond what was authorised).
select pg_temp.put('u2', 100001);
set local role service_role;
select is(public.begin_media_processing((select value::uuid from fx where key = 'u2'), (select value::uuid from fx where key = 'owner'))->>'code', 'too_large', 'an object larger than the authorised ceiling is rejected');
reset role;
select is((select failure_code from private.media_uploads where id = (select value::uuid from fx where key = 'u2')), 'too_large', 'recorded as too_large');

-- Expired authorisation, object never arrived.
update private.media_uploads set expires_at = now() - interval '1 minute' where id = (select value::uuid from fx where key = 'u3');
set local role service_role;
select is(public.begin_media_processing((select value::uuid from fx where key = 'u3'), (select value::uuid from fx where key = 'owner'))->>'status', 'expired', 'an expired authorisation with no object fails');
reset role;
select is((select status from private.media_uploads where id = (select value::uuid from fx where key = 'u3')), 'expired', 'and is marked expired');

-- Object written AFTER the authorisation expired (late upload with a still-valid token).
select pg_temp.put('u4');
update private.media_uploads set expires_at = now() - interval '5 minutes' where id = (select value::uuid from fx where key = 'u4');
update storage.objects set created_at = now()
  where bucket_id = 'media-quarantine' and name = (select object_path from private.media_uploads where id = (select value::uuid from fx where key = 'u4'));
set local role service_role;
select is(public.begin_media_processing((select value::uuid from fx where key = 'u4'), (select value::uuid from fx where key = 'owner'))->>'code', 'expired', 'a file that arrived after expiry is never processed');
reset role;

-- Rejections record a short code only.
select pg_temp.put('u5');
set local role service_role;
select public.begin_media_processing((select value::uuid from fx where key = 'u5'), (select value::uuid from fx where key = 'owner'));
select throws_like(format($sql$ select public.reject_media_upload(%L::uuid, 'Not an image: secret path /x') $sql$, (select value from fx where key = 'u5')),
  'validation_failed:%', 'free text is not accepted as a failure code');
select public.reject_media_upload((select value::uuid from fx where key = 'u5'), 'not_an_image');
reset role;
select is((select status || ':' || failure_code from private.media_uploads where id = (select value::uuid from fx where key = 'u5')),
  'rejected:not_an_image', 'a content failure ends rejected');
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(public.get_media_upload((select value::uuid from fx where key = 'u5'))->>'failureCode', 'not_an_image',
  'the owner sees a clear state and code');
select throws_ok(format($sql$ select public.begin_media_processing(%L::uuid, %L::uuid) $sql$,
  (select value from fx where key = 'u5'), (select value from fx where key = 'owner')),
  '42501', null, 'API roles cannot start processing');
reset role;

select * from finish();
rollback;
