-- Phases 025/026/029: owner writes go through checked RPCs only.
-- Phone range +91900000080x.
begin;
select plan(25);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');

-- GoTrue stores the phone WITHOUT '+': create that user directly.
insert into auth.users (id, instance_id, aud, role, phone, phone_confirmed_at, created_at, updated_at)
values ('00000000-0000-0000-0000-0000000008a1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', '919000000801', now(), now(), now());
insert into fx values
  ('owner', '00000000-0000-0000-0000-0000000008a1'),
  ('other', tests.create_phone_user('+919000000802')::text);
-- "other" is itself a provider with a published listing and a consent row.
insert into fx select 'other_pid', tests.create_published_provider(
  (select value::uuid from fx where key = 'other'), '+919000000802', 'Other Provider')::text;
insert into public.consent_records (provider_id, kind, granted, phone_e164)
  values ((select value::uuid from fx where key = 'other_pid'), 'display_phone_number', true, '+919000000802');

-- ---------------------------------------------------------------------------
-- Registration: normalisation, duplicate payload entries, idempotency.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
insert into fx values ('reg1', public.register_profile(json_build_object(
  'displayName', 'Owner Write Listing', 'baseCityId', 'test-active-city', 'baseLocalityId', 'test-locality-a',
  'phoneDisplayConsented', true, 'idempotencyKey', 'idem-key-0001',
  'categoryIds', jsonb_build_array('test-category-plumbing', 'test-category-plumbing'),
  'serviceAreaIds', jsonb_build_array('test-locality-a', 'test-locality-a', 'test-locality-b'))::jsonb)::text);
reset role;
insert into fx values ('pid', (select value::jsonb->>'id' from fx where key = 'reg1'));

select is(
  (select phone_e164 from public.provider_profiles where id = (select value::uuid from fx where key = 'pid')),
  '+919000000801', 'register_profile normalises a GoTrue phone without "+" to E.164'
);
select is(
  (select count(*)::int from public.provider_categories where provider_id = (select value::uuid from fx where key = 'pid')),
  1, 'duplicate categoryIds produce one child row'
);
select is(
  (select count(*)::int from public.provider_service_areas where provider_id = (select value::uuid from fx where key = 'pid')),
  2, 'duplicate serviceAreaIds produce one child row each'
);

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(
  (public.get_owner_profile((select value::uuid from fx where key = 'pid')))->'verification'->>'phone',
  'approved', 'registration records phone verification (owner json verification.phone = approved)'
);

select throws_like(
  $sql$ select public.register_profile('{"displayName":"Again","baseCityId":"test-active-city","baseLocalityId":"test-locality-a","categoryIds":["test-category-plumbing"],"serviceAreaIds":["test-locality-a"]}'::jsonb) $sql$,
  '%conflict:%', 'registering a second time for the same account is a conflict'
);

select is(
  public.register_profile(json_build_object(
    'displayName', 'Owner Write Listing', 'baseCityId', 'test-active-city', 'baseLocalityId', 'test-locality-a',
    'phoneDisplayConsented', true, 'idempotencyKey', 'idem-key-0001',
    'categoryIds', jsonb_build_array('test-category-plumbing', 'test-category-plumbing'),
    'serviceAreaIds', jsonb_build_array('test-locality-a', 'test-locality-a', 'test-locality-b'))::jsonb),
  (select value::jsonb from fx where key = 'reg1'),
  'same idempotency key and payload returns the identical response'
);

select throws_like(
  $sql$ select public.register_profile('{"displayName":"Changed","baseCityId":"test-active-city","baseLocalityId":"test-locality-a","idempotencyKey":"idem-key-0001","categoryIds":["test-category-plumbing"],"serviceAreaIds":["test-locality-a"]}'::jsonb) $sql$,
  '%conflict:%', 'same idempotency key with a changed payload is a conflict'
);
reset role;
select is(
  (select count(*)::int from public.provider_profiles where user_id = '00000000-0000-0000-0000-0000000008a1'),
  1, 'retries left exactly one profile'
);

-- ---------------------------------------------------------------------------
-- Direct table writes are closed for signed-in users, including the squatter.
select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select throws_ok(
  $sql$ insert into public.provider_profiles (user_id, phone_e164, display_name, base_city_id, base_locality_id)
        values (auth.uid(), '+919000000801', 'Squatter', 'test-active-city', 'test-locality-a') $sql$,
  '42501', null, 'a signed-in user cannot insert a profile row carrying someone else''s phone'
);

-- Read isolation: a signed-in provider sees only their own profile row, even
-- though another provider's listing ('other_pid') is published.
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(
  (select count(*)::int from public.provider_profiles), 1,
  'a provider counts exactly one profile row (their own) although other listings are published'
);
select is_empty(
  format($sql$ select phone_e164, user_id, map_lat from public.provider_profiles where id = %L $sql$,
         (select value from fx where key = 'other_pid')),
  'a provider cannot select phone_e164/user_id/map_lat of someone else''s PUBLISHED row'
);
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select ok(
  (select count(*) from public.consent_records) >= 3
  and not exists (select 1 from public.consent_records where provider_id <> (select value::uuid from fx where key = 'pid')),
  'the owner reads only their own consent_records'
);
select is(
  (select count(*)::int from public.consent_records where provider_id = (select value::uuid from fx where key = 'other_pid')),
  0, 'the owner cannot read another provider''s consent_records'
);
select throws_ok(
  format($sql$ update public.provider_profiles set display_name = 'Direct' where id = %L $sql$, (select value from fx where key = 'pid')),
  '42501', null, 'the owner cannot UPDATE provider_profiles directly'
);
select throws_ok(
  format($sql$ delete from public.provider_profiles where id = %L $sql$, (select value from fx where key = 'pid')),
  '42501', null, 'the owner cannot DELETE provider_profiles directly'
);
select throws_ok(
  format($sql$ insert into public.provider_categories (provider_id, category_id) values (%L, 'test-category-electrical') $sql$,
         (select value from fx where key = 'pid')),
  '42501', null, 'the owner cannot INSERT child rows directly'
);
select throws_ok(
  format($sql$ delete from public.provider_service_areas where provider_id = %L $sql$, (select value from fx where key = 'pid')),
  '42501', null, 'the owner cannot DELETE child rows directly'
);

-- Atomicity: an invalid locality rejects the whole patch.
select lives_ok(
  format($sql$ select public.update_profile_full(%L::uuid,
    '{"workingHours":{"days":[{"weekday":2,"open":540,"close":1080}]}}'::jsonb) $sql$, (select value from fx where key = 'pid')),
  'a valid patch sets working hours'
);
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, %L::jsonb) $sql$, (select value from fx where key = 'pid'),
    '{"categoryIds":["test-category-electrical"],"workingHours":{"days":[{"weekday":5,"open":1,"close":2}]},"serviceAreas":[{"localityId":"test-locality-c-other-city"}]}'),
  '%validation_failed:%', 'an invalid locality is rejected'
);
reset role;
select ok(
  (select array_agg(category_id) from public.provider_categories where provider_id = (select value::uuid from fx where key = 'pid'))
    = array['test-category-plumbing']
  and (select array_agg(weekday) from public.provider_working_hours where provider_id = (select value::uuid from fx where key = 'pid'))
    = array[2]::smallint[],
  'the rejected patch left categories and working hours unchanged'
);

-- ---------------------------------------------------------------------------
-- Another owner is refused by every RPC.
select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, '{"displayName":"Hijack"}'::jsonb) $sql$, (select value from fx where key = 'pid')),
  '%not_owner:%', 'another owner cannot update_profile_full');
select throws_like(
  format($sql$ select public.set_listing_status(%L::uuid, 'paused') $sql$, (select value from fx where key = 'pid')),
  '%not_owner:%', 'another owner cannot set_listing_status');
select throws_like(
  format($sql$ select public.delete_listing(%L::uuid) $sql$, (select value from fx where key = 'pid')),
  '%not_owner:%', 'another owner cannot delete_listing');
select throws_like(
  format($sql$ select public.add_provider_photo(%L::uuid, %L) $sql$, (select value from fx where key = 'pid'),
         (select value from fx where key = 'other') || '/x.jpg'),
  '%not_owner:%', 'another owner cannot add_provider_photo');
reset role;

-- Photo path must sit in the caller's own folder.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.add_provider_photo(%L::uuid, %L) $sql$, (select value from fx where key = 'pid'),
         (select value from fx where key = 'other') || '/x.jpg'),
  '%validation_failed:%', 'a photo path outside the owner''s folder is rejected');
reset role;

select * from finish();
rollback;
