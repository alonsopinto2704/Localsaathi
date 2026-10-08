-- Phase 082 (migration 0031): owner-bound upload authorization. Phones +91900031xxxx.
-- The storage-side half (signed upload URL bound to the path, token expiry) is
-- platform behaviour and NOT exercised here; see tasks/evidence/phase-082.md.
begin;
select plan(17);
select tests.ensure_reference_data();
select tests.set_flag('media_intake', true);
select tests.set_flag('media_pipeline', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('owner', tests.create_phone_user('+919000310001')::text),
  ('other', tests.create_phone_user('+919000310002')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000310001', 'Upload Listing')::text;
insert into fx select 'b', tests.create_published_provider(
  (select value::uuid from fx where key = 'other'), '+919000310002', 'Other Upload Listing')::text;

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
insert into fx select 'issued', public.request_media_upload((select value::uuid from fx where key = 'a'),
  'portfolio_original', 'image/jpeg', 200000)::text;
select is((select value::jsonb->>'bucket' from fx where key = 'issued'), 'media-quarantine', 'the upload targets the private quarantine bucket');
select matches((select value::jsonb->>'path' from fx where key = 'issued'),
  '^' || (select value from fx where key = 'a') || '/[0-9a-f-]{36}$', 'the path is generated: <listing id>/<upload id>');
select ok(pg_get_function_arguments('public.request_media_upload(uuid,text,text,int)'::regprocedure) !~* 'path|name|key',
  'the request has no parameter through which a client could choose a path');
select is(public.get_media_upload(((select value::jsonb->>'uploadId' from fx where key = 'issued'))::uuid)->>'status', 'issued',
  'the owner can read the state of their own upload');
reset role;
select is((select user_id::text from private.media_uploads where id = ((select value::jsonb->>'uploadId' from fx where key = 'issued'))::uuid),
  (select value from fx where key = 'owner'), 'the row binds the upload to the issuing account');
select ok((select expires_at from private.media_uploads where id = ((select value::jsonb->>'uploadId' from fx where key = 'issued'))::uuid)
  between now() + interval '14 minutes' and now() + interval '16 minutes', 'authorisation expires in about 15 minutes');

select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select is(public.get_media_upload(((select value::jsonb->>'uploadId' from fx where key = 'issued'))::uuid), 'null'::jsonb,
  'another account sees nothing of that upload');
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/jpeg', 1000) $sql$, (select value from fx where key = 'a')),
  'not_owner:%', 'an account cannot obtain an upload for someone else''s listing');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'application/x-msdownload', 1000) $sql$, (select value from fx where key = 'a')),
  'validation_failed:%', 'a non-image MIME is refused');
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/svg+xml', 1000) $sql$, (select value from fx where key = 'a')),
  'validation_failed:%', 'SVG (scriptable) is refused');
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/jpeg', 8388609) $sql$, (select value from fx where key = 'a')),
  'validation_failed:%', 'above the byte ceiling is refused');
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/jpeg', 0) $sql$, (select value from fx where key = 'a')),
  'validation_failed:%', 'an empty file is refused');
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'credential_evidence', 'image/jpeg', 1000) $sql$, (select value from fx where key = 'a')),
  'validation_failed:%', 'other classes cannot be requested through this function');

-- Open-upload cap per listing (1 issued above + 9 more = 10; the 11th is refused).
do $$ begin
  for i in 1..9 loop
    perform public.request_media_upload((select value::uuid from fx where key = 'a'), 'portfolio_original', 'image/png', 1000);
  end loop;
end $$;
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/png', 1000) $sql$, (select value from fx where key = 'a')),
  'rate_limited:%', 'too many pending uploads for one listing are refused');
reset role;

-- Suspended listings and switched-off intake.
select tests.moderate_as_admin((select value::uuid from fx where key = 'b'), 'suspended', 'test');
select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/png', 1000) $sql$, (select value from fx where key = 'b')),
  'not_owner:%', 'a suspended listing cannot start uploads');
reset role;
select tests.set_flag('media_pipeline', false);
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/png', 1000) $sql$, (select value from fx where key = 'a')),
  'feature_disabled:%', 'with the pipeline off, no upload is issued (safe stop)');
reset role;

select tests.authenticate_as_anon();
select throws_ok(
  format($sql$ select public.request_media_upload(%L::uuid, 'portfolio_original', 'image/png', 1000) $sql$, (select value from fx where key = 'a')),
  '42501', null, 'anon cannot call it');
reset role;

select * from finish();
rollback;
