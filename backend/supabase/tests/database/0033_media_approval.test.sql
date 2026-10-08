-- Phases 084/086 (migration 0033): the approval gate and byte budgets. Phones +91900033xxxx.
-- Metadata stripping and the metadata scanner are Edge Function code, tested in
-- backend/test/media-process.test.mjs; this suite covers what the database
-- refuses to approve.
begin;
select plan(14);
select tests.ensure_reference_data();
select tests.set_flag('media_intake', true);
select tests.set_flag('media_pipeline', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('owner', tests.create_phone_user('+919000330001')::text),
  ('other', tests.create_phone_user('+919000330002')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000330001', 'Approval Listing')::text;
insert into fx select 'b', tests.create_published_provider(
  (select value::uuid from fx where key = 'other'), '+919000330002', 'Other Approval Listing')::text;

-- An upload in processing, plus its two derivative objects written to the public bucket.
insert into fx select 'u', tests.media_upload((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'owner'), 'processing')::text;
insert into fx select 'k', (select value from fx where key = 'a') || '/' || (select value from fx where key = 'u');
insert into storage.objects (bucket_id, name, metadata) values
  ('provider-photos', (select value from fx where key = 'k') || '-thumb.webp', '{"size": 5000}'),
  ('provider-photos', (select value from fx where key = 'k') || '-full.webp', '{"size": 20000}');

create function pg_temp.complete(p_thumb text, p_full text, p_tb int, p_fb int, p_w int, p_h int, p_clean boolean) returns void language sql as $$
  select public.complete_media_upload((select value::uuid from fx where key = 'u'), p_thumb, p_full, p_tb, p_fb, p_w, p_h, p_clean);
$$;
grant execute on function pg_temp.complete(text, text, int, int, int, int, boolean) to service_role;

set local role service_role;
select throws_like($$ select pg_temp.complete((select value from fx where key = 'k') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 20000, 800, 600, false) $$,
  'validation_failed: derivatives were not verified%', 'metadata-free verification is mandatory for approval');
select throws_like($$ select pg_temp.complete((select value from fx where key = 'a') || '/chosen-by-caller-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 20000, 800, 600, true) $$,
  'validation_failed: derivative keys%', 'a caller-chosen key cannot be approved');
select throws_like($$ select pg_temp.complete((select value from fx where key = 'b') || '/' || (select value from fx where key = 'u') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 20000, 800, 600, true) $$,
  'validation_failed: derivative keys%', 'another listing''s folder cannot be approved for this upload');
select throws_like($$ select pg_temp.complete((select value from fx where key = 'k') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 40961, 20000, 800, 600, true) $$,
  'validation_failed: derivative exceeds%', 'a thumbnail over 40 KB is not approved');
select throws_like($$ select pg_temp.complete((select value from fx where key = 'k') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 307201, 800, 600, true) $$,
  'validation_failed: derivative exceeds%', 'a full image over 300 KB is not approved');
select throws_like($$ select pg_temp.complete((select value from fx where key = 'k') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 20000, 4000, 3000, true) $$,
  'validation_failed: derivative dimensions%', 'original-resolution output is not approved (display need only)');
reset role;

-- Blobs missing: the claim cannot be approved without the objects.
delete from storage.objects where bucket_id = 'provider-photos' and name = (select value from fx where key = 'k') || '-thumb.webp';
set local role service_role;
select throws_like($$ select pg_temp.complete((select value from fx where key = 'k') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 20000, 800, 600, true) $$,
  'conflict: derivative objects%', 'approval requires both derivative objects to exist');
reset role;
insert into storage.objects (bucket_id, name, metadata) values ('provider-photos', (select value from fx where key = 'k') || '-thumb.webp', '{"size": 5000}');

set local role service_role;
select lives_ok($$ select pg_temp.complete((select value from fx where key = 'k') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 20000, 800, 600, true) $$,
  'a verified, in-budget, correctly keyed pair is approved');
select lives_ok($$ select pg_temp.complete((select value from fx where key = 'k') || '-thumb.webp', (select value from fx where key = 'k') || '-full.webp', 5000, 20000, 800, 600, true) $$,
  'repeating the same completion is idempotent');
reset role;
select is((select status || ':' || full_path from private.media_uploads where id = (select value::uuid from fx where key = 'u')),
  'approved:' || (select value from fx where key = 'k') || '-full.webp', 'the upload is approved with its full-derivative path');
select is((select count(*)::int from private.audit_events where action = 'media_upload_approved' and target_id = (select value from fx where key = 'u')),
  1, 'approval is audited once');

-- A rejected/issued upload can never be completed.
insert into fx select 'i', tests.media_upload((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'owner'), 'issued')::text;
set local role service_role;
select throws_like(format($sql$ select public.complete_media_upload(%L::uuid, 'x', 'y', 1, 1, 1, 1, true) $sql$, (select value from fx where key = 'i')),
  'conflict: upload is issued%', 'only a processing upload can be completed');
reset role;

-- Budgets are the documented numbers, and API roles cannot approve anything.
select is((select array_agg(kind || ':' || max_edge || ':' || max_bytes order by kind) from private.media_derivatives),
  array['full:1280:307200', 'thumb:320:40960'], 'the budget table holds exactly the two documented derivatives');
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_ok($$ select public.complete_media_upload(gen_random_uuid(), 'x', 'y', 1, 1, 1, 1, true) $$, '42501', null,
  'an owner cannot approve their own upload');
reset role;

select * from finish();
rollback;
