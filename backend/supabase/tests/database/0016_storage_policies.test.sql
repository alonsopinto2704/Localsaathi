-- Phase 006 gap: storage.objects policies (provider-photos keyed by listing
-- since 0022; credential-evidence private, keyed by user). SQL-level only:
-- whether Storage serves public-bucket objects without a SELECT policy is
-- platform behaviour, covered by the HTTP pack (phase 039).
-- Phone range +91900000160x.
begin;
select plan(7);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('owner', tests.create_phone_user('+919000001601')::text);
insert into fx values ('other', tests.create_phone_user('+919000001602')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000001601', 'Storage Listing')::text;
insert into fx select 'b', tests.create_published_provider(
  (select value::uuid from fx where key = 'other'), '+919000001602', 'Other Listing')::text;
insert into storage.objects (bucket_id, name)
  values ('credential-evidence', (select value from fx where key = 'owner') || '/reg.pdf');

-- provider-photos: only into a listing the caller owns.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('provider-photos', %L) $sql$,
         (select value from fx where key = 'a') || '/p1.jpg'),
  'an owner can upload into their own listing folder');
select throws_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('provider-photos', %L) $sql$,
         (select value from fx where key = 'b') || '/p1.jpg'),
  '42501', null, 'an owner cannot upload into another listing''s folder');
select throws_ok(
  format($sql$ insert into storage.objects (bucket_id, name) values ('provider-photos', %L) $sql$,
         (select value from fx where key = 'owner') || '/p1.jpg'),
  '42501', null, 'the legacy user-id folder is no longer writable');
select is(
  (select count(*)::int from storage.objects where bucket_id = 'credential-evidence'),
  1, 'an owner can see their own credential evidence');
reset role;

-- credential-evidence: invisible to another provider and to anon.
select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select is(
  (select count(*)::int from storage.objects where bucket_id = 'credential-evidence'),
  0, 'another provider cannot see someone else''s credential evidence');
with d as (delete from storage.objects where bucket_id = 'provider-photos' returning 1)
select is((select count(*)::int from d), 0, 'another provider cannot delete someone else''s photos');
reset role;
select tests.authenticate_as_anon();
select is(
  (select count(*)::int from storage.objects where bucket_id = 'credential-evidence'),
  0, 'anon cannot see any credential evidence');
reset role;

select * from finish();
rollback;
