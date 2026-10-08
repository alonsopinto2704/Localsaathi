-- Phase 081 (migration 0030): storage classification contract. Phones +91900030xxxx.
-- SQL-level only: whether real Storage/CDN enforces these (bucket limits, public
-- URLs, signed links) is platform behaviour, covered by the HTTP pack once a
-- hosted project exists.
begin;
select plan(14);
select tests.ensure_reference_data();
select tests.set_flag('media_intake', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values ('owner', tests.create_phone_user('+919000300001')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000300001', 'Media Class Listing')::text;

-- Buckets are generated from the class table; nothing drifts.
select is((select count(*)::int from private.media_classes c join storage.buckets b on b.id = c.bucket_id
           where b.public = c.is_public and b.file_size_limit = c.max_bytes and b.allowed_mime_types = c.allowed_mime),
          (select count(*)::int from private.media_classes), 'every class has a bucket with the same public flag, size limit and MIME list');
select is((select array_agg(bucket_id order by bucket_id) from private.media_classes where is_public),
          array['provider-photos'], 'only the derivative bucket is public');
select is((select count(*)::int from storage.buckets b where b.public and b.id not in (select bucket_id from private.media_classes)),
          0, 'no public bucket exists outside the classification');
select is((select enabled from public.feature_flags where key = 'media_pipeline'), false,
          'the pipeline ships OFF (staged cutover); media_intake is a separate switch');

-- Private classes: no client can write, whatever the folder.
insert into storage.buckets (id, name) values ('scratch-unclassified', 'scratch-unclassified');
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('media-quarantine', %L) $sql$,
         (select value from fx where key = 'a') || '/' || gen_random_uuid()),
  '42501', null, 'an owner cannot write to quarantine, even into their own listing folder');
select throws_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('ai-attachments', %L) $sql$,
         (select value from fx where key = 'owner') || '/x.png'),
  '42501', null, 'the reserved AI bucket accepts no client write');
select throws_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('scratch-unclassified', %L) $sql$,
         (select value from fx where key = 'owner') || '/x.png'),
  '42501', null, 'an unclassified bucket is private by default (no policy)');
reset role;

-- The public bucket, pipeline off: pre-081 behaviour is unchanged.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('provider-photos', %L) $sql$,
         (select value from fx where key = 'a') || '/legacy.jpg'),
  'pipeline off: the owner folder rule still applies (legacy path)');
reset role;

-- Pipeline on: only the service role writes the public bucket.
select tests.set_flag('media_pipeline', true);
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('provider-photos', %L) $sql$,
         (select value from fx where key = 'a') || '/direct.jpg'),
  '42501', null, 'pipeline on: a client cannot upload straight to the public bucket');
with u as (update storage.objects set name = name || 'x' where bucket_id = 'provider-photos' returning 1)
select is((select count(*)::int from u), 0, 'pipeline on: a client cannot rename or replace public objects');
with d as (delete from storage.objects where bucket_id = 'provider-photos' returning 1)
select is((select count(*)::int from d), 0, 'pipeline on: a client cannot delete public objects (removal goes through the RPC and sweep)');
reset role;
set local role service_role;
select lives_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('provider-photos', %L) $sql$,
         (select value from fx where key = 'a') || '/derived.webp'),
  'the service role (pipeline) can still write derivatives');
reset role;

-- Anon cannot enumerate quarantine; the matrix is not client-readable.
select tests.authenticate_as_anon();
select is((select count(*)::int from storage.objects where bucket_id = 'media-quarantine'), 0, 'anon sees nothing in quarantine');
select throws_ok($$ select * from private.media_classes $$, '42501', null, 'the class table is not readable by API roles');
reset role;

select * from finish();
rollback;
