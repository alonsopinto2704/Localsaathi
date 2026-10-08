-- Phase 085 (migration 0034): interrupted uploads and orphan selection. Phones +91900034xxxx.
-- This proves WHICH objects the sweep may list. Actually removing blobs goes
-- through the Storage API (media-gc) and is NOT exercised here: no hosted project.
begin;
select plan(19);
select tests.ensure_reference_data();
select tests.set_flag('media_intake', true);
select tests.set_flag('media_pipeline', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('owner', tests.create_phone_user('+919000340001')::text),
  ('other', tests.create_phone_user('+919000340002')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000340001', 'Orphan Listing')::text;
insert into fx select 'b', tests.create_published_provider(
  (select value::uuid from fx where key = 'other'), '+919000340002', 'Other Orphan Listing')::text;

-- Everything below starts fresh and "old" (3 hours) unless a case says otherwise.
create function pg_temp.age(p_bucket text, p_name text, p_age interval default interval '3 hours') returns void language sql as $$
  update storage.objects set created_at = now() - p_age where bucket_id = p_bucket and name = p_name;
$$;
create function pg_temp.listed(p_bucket text, p_name text) returns boolean language sql as $$
  select coalesce(bool_or(i->>'bucket' = p_bucket and i->>'name' = p_name), false)
  from jsonb_array_elements(public.list_media_orphans(500, true)->'items') i;
$$;

-- Quarantine cases.
insert into storage.objects (bucket_id, name) values
  ('media-quarantine', (select value from fx where key = 'a') || '/' || gen_random_uuid()),   -- no row, old
  ('media-quarantine', (select value from fx where key = 'a') || '/' || gen_random_uuid());   -- no row, fresh
insert into fx select 'q_old', min(name) from storage.objects where bucket_id = 'media-quarantine';
insert into fx select 'q_new', max(name) from storage.objects where bucket_id = 'media-quarantine';
-- min/max by name is arbitrary; make the roles explicit:
update storage.objects set created_at = now() - interval '3 hours' where bucket_id = 'media-quarantine' and name = (select value from fx where key = 'q_old');
update storage.objects set created_at = now() - interval '10 minutes' where bucket_id = 'media-quarantine' and name = (select value from fx where key = 'q_new');
insert into fx select 'issued', tests.media_upload((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'owner'), 'issued')::text;
insert into fx select 'processing', tests.media_upload((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'owner'), 'processing')::text;
insert into fx select 'rejected', tests.media_upload((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'owner'), 'rejected')::text;
create function pg_temp.opath(p text) returns text language sql as $$
  select object_path from private.media_uploads where id = p::uuid;
$$;

select is(pg_temp.listed('media-quarantine', (select value from fx where key = 'q_old')), true, 'a quarantine object with no upload row is removable after the grace period');
select is(pg_temp.listed('media-quarantine', (select value from fx where key = 'q_new')), false, 'a fresh one is left alone (the upload may still be finishing)');
select is(pg_temp.listed('media-quarantine', pg_temp.opath((select value from fx where key = 'issued'))), false, 'an issued upload inside its window is never removed');
select is(pg_temp.listed('media-quarantine', pg_temp.opath((select value from fx where key = 'processing'))), false, 'a processing upload is never removed');
select is(pg_temp.listed('media-quarantine', pg_temp.opath((select value from fx where key = 'rejected'))), false, 'a just-rejected original waits out the short window');
update private.media_uploads set processed_at = now() - interval '2 hours' where id = (select value::uuid from fx where key = 'rejected');
select is(pg_temp.listed('media-quarantine', pg_temp.opath((select value from fx where key = 'rejected'))), true, 'a rejected original is removed once the window is over');
update private.media_uploads set expires_at = now() - interval '3 hours' where id = (select value::uuid from fx where key = 'issued');
select is(pg_temp.listed('media-quarantine', pg_temp.opath((select value from fx where key = 'issued'))), true, 'an abandoned (expired + grace) upload''s file is removable');
insert into fx select 'gone', tests.media_upload((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'owner'), 'issued', false)::text;
update private.media_uploads set expires_at = now() - interval '1 hour' where id = (select value::uuid from fx where key = 'gone');
select public.expire_media_uploads();
select is((select status from private.media_uploads where id = (select value::uuid from fx where key = 'gone')), 'expired', 'the sweep marks a never-uploaded, lapsed authorisation expired');

-- Public bucket cases.
insert into fx select 'ap', tests.media_upload((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'owner'), 'approved')::text;
create function pg_temp.full(p text) returns text language sql as $$ select full_path from private.media_uploads where id = p::uuid; $$;
create function pg_temp.thumb(p text) returns text language sql as $$ select thumb_path from private.media_uploads where id = p::uuid; $$;
select pg_temp.age('provider-photos', pg_temp.full((select value from fx where key = 'ap')));
select pg_temp.age('provider-photos', pg_temp.thumb((select value from fx where key = 'ap')));
select is(pg_temp.listed('provider-photos', pg_temp.full((select value from fx where key = 'ap'))), false, 'derivatives of an approved upload are referenced and kept');
update private.media_uploads set status = 'retired' where id = (select value::uuid from fx where key = 'ap');
select is(pg_temp.listed('provider-photos', pg_temp.thumb((select value from fx where key = 'ap'))), true, 'once the photo is retired both derivatives become orphans');

-- Reference ownership: a photo row of ANOTHER listing naming a path protects nothing.
insert into storage.objects (bucket_id, name, created_at) values
  ('provider-photos', (select value from fx where key = 'a') || '/legacy-kept.jpg', now() - interval '3 hours'),
  ('provider-photos', (select value from fx where key = 'a') || '/stolen-ref.jpg', now() - interval '3 hours'),
  ('provider-photos', (select value from fx where key = 'a') || '/young.jpg', now() - interval '5 minutes');
insert into public.provider_photos (provider_id, caption, storage_path) values
  ((select value::uuid from fx where key = 'a'), '', (select value from fx where key = 'a') || '/legacy-kept.jpg'),
  ((select value::uuid from fx where key = 'b'), '', (select value from fx where key = 'a') || '/stolen-ref.jpg');
select is(pg_temp.listed('provider-photos', (select value from fx where key = 'a') || '/legacy-kept.jpg'), false, 'an object referenced by its own listing is kept');
select is(pg_temp.listed('provider-photos', (select value from fx where key = 'a') || '/stolen-ref.jpg'), true, 'a reference from another listing does not protect it');
select is(pg_temp.listed('provider-photos', (select value from fx where key = 'a') || '/young.jpg'), false, 'an unreferenced but recent object waits for the grace period');

-- Odd shapes and other buckets are never listed, however old.
insert into storage.objects (bucket_id, name, created_at) values
  ('provider-photos', 'not-a-uuid/file.jpg', now() - interval '9 days'),
  ('provider-photos', (select value from fx where key = 'a') || '/nested/deep.jpg', now() - interval '9 days'),
  ('credential-evidence', (select value from fx where key = 'owner') || '/reg.pdf', now() - interval '9 days');
select is(pg_temp.listed('provider-photos', 'not-a-uuid/file.jpg') or pg_temp.listed('provider-photos', (select value from fx where key = 'a') || '/nested/deep.jpg'),
  false, 'objects outside the <uuid>/<file> shape are never deleted');
select is(pg_temp.listed('credential-evidence', (select value from fx where key = 'owner') || '/reg.pdf'), false, 'credential evidence is out of scope for this sweep');

-- Pause conditions.
select tests.set_flag('media_cleanup', false);
select is(public.list_media_orphans()->>'paused', 'media_cleanup_off', 'cleanup pauses while the kill switch is off');
select is(public.media_object_deletable('media-quarantine', (select value from fx where key = 'q_old')), false, 'and the pre-delete re-check refuses too');
select tests.set_flag('media_cleanup', true);
insert into storage.objects (bucket_id, name, created_at)
  select 'provider-photos', (select value from fx where key = 'b') || '/' || gen_random_uuid() || '.jpg', now() - interval '3 hours' from generate_series(1, 25);
select is(public.list_media_orphans()->>'paused', 'anomaly', 'a sweep that would delete most of a bucket pauses for human review');

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_ok($$ select public.list_media_orphans() $$, '42501', null, 'API roles cannot list or sweep');
reset role;

select * from finish();
rollback;
