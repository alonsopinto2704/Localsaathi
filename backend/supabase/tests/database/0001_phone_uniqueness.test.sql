begin;
select plan(3);
select tests.ensure_reference_data();

-- "One verified phone number = one account = one public profile", enforced
-- by Postgres itself (provider_profiles.phone_e164 UNIQUE,
-- provider_profiles.user_id UNIQUE), not merely checked in application code.
-- This is also the "concurrent duplicate creation is rejected" guarantee: a
-- UNIQUE constraint is checked by the database on every insert, so two
-- simultaneous transactions racing to insert the same phone cannot both
-- succeed -- one always hits this same error, whichever one wins the race.

-- A plain temp table carries generated ids between statements. Deliberately
-- not psql's `\gset`: pgTAP/pg_prove may run these files through a non-psql
-- client, and \gset would silently fail to do anything there.
create temporary table fx (key text primary key, value text);

insert into fx values
  ('user1', tests.create_phone_user('+919000000001')::text),
  ('user2', tests.create_phone_user('+919000000002')::text);

insert into fx
  select 'p1', tests.create_published_provider(
    (select value::uuid from fx where key = 'user1'), '+919000000001', 'Provider One'
  )::text;

select throws_like(
  format(
    $sql$ insert into public.provider_profiles (user_id, phone_e164, display_name, base_city_id, base_locality_id)
          values (%L, '+919000000001', 'Duplicate phone', 'test-active-city', 'test-locality-a') $sql$,
    (select value::uuid from fx where key = 'user2')
  ),
  '%duplicate key value%',
  'a second profile cannot be created for a phone number that already owns one'
);

select throws_like(
  format(
    $sql$ insert into public.provider_profiles (user_id, phone_e164, display_name, base_city_id, base_locality_id)
          values (%L, '+919000000099', 'Second profile same account', 'test-active-city', 'test-locality-a') $sql$,
    (select value::uuid from fx where key = 'user1')
  ),
  '%duplicate key value%',
  'a second profile cannot be created for an account that already has one'
);

select isnt_empty(
  format($sql$ select 1 from public.provider_profiles where id = %L $sql$, (select value::uuid from fx where key = 'p1')),
  'the original provider profile is unaffected by the rejected duplicates'
);

select * from finish();
rollback;
