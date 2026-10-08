-- Phase 091 (migration 0042): precise location needs explicit consent;
-- locality-only profiles expose no coordinates. Phones +91900042xxxx.
begin;
select plan(27);
select tests.ensure_reference_data();
select tests.set_flag('precise_location', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('owner', tests.create_phone_user('+919000420001')::text),
  ('other', tests.create_phone_user('+919000420002')::text);
insert into fx select 'a', tests.create_published_provider((select value::uuid from fx where key = 'owner'), '+919000420001', 'Pin Listing')::text;
insert into fx select 'b', tests.create_published_provider((select value::uuid from fx where key = 'other'), '+919000420002', 'Area Only Listing')::text;
grant all on fx to authenticated;

create function pg_temp.pin(p_key text) returns jsonb language sql as $$
  select public.get_public_profile((select value::uuid from fx where key = p_key))->'mapLocation' $$;
grant execute on function pg_temp.pin(text) to anon, authenticated;

-- A coordinate that predates the new wording stays hidden.
update public.provider_profiles set map_lat = 19.07612, map_lng = 72.87771 where id = (select value::uuid from fx where key = 'a');
select tests.authenticate_as_anon();
select is(pg_temp.pin('a'), 'null'::jsonb, 'a stored pin with no consent in the new wording is not public, even with the flag on');
reset role;
update public.provider_profiles set map_lat = null, map_lng = null where id = (select value::uuid from fx where key = 'a');

-- Opting in.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.set_location_disclosure(%L, 'approximate_pin', 19.07612, 72.87771) $sql$, (select value from fx where key = 'a')),
  'consent_required%', 'a pin needs the current wording version');
select throws_like(
  format($sql$ select public.set_location_disclosure(%L, 'approximate_pin', 19.07612, 72.87771, 'location-v1') $sql$, (select value from fx where key = 'a')),
  'consent_required%', 'an old wording version does not count');
select throws_like(
  format($sql$ select public.set_location_disclosure(%L, 'approximate_pin', 51.5, -0.12, 'location-v2') $sql$, (select value from fx where key = 'a')),
  'validation_failed%', 'a pin must be inside India');
select throws_like(
  format($sql$ select public.set_location_disclosure(%L, 'approximate_pin', null, null, 'location-v2') $sql$, (select value from fx where key = 'a')),
  'validation_failed%', 'a pin needs both coordinates');
select throws_like(
  format($sql$ select public.set_location_disclosure(%L, 'exact_home', 19.07612, 72.87771, 'location-v2') $sql$, (select value from fx where key = 'a')),
  'validation_failed%', 'there is no exact-location mode');
select throws_like(
  format($sql$ select public.set_map_location(%L, 19.07612, 72.87771) $sql$, (select value from fx where key = 'a')),
  'validation_failed%', 'the old setter can no longer share a pin');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select throws_like(
  format($sql$ select public.set_location_disclosure(%L, 'approximate_pin', 19.07612, 72.87771, 'location-v2') $sql$, (select value from fx where key = 'a')),
  'not_owner%', 'nobody else can set it');
reset role;
select tests.authenticate_as_anon();
select throws_ok(format($sql$ select public.set_location_disclosure(%L, 'locality_only') $sql$, (select value from fx where key = 'a')),
  '42501', null, 'a guest cannot call it');
reset role;

select tests.set_flag('precise_location', false);
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.set_location_disclosure(%L, 'approximate_pin', 19.07612, 72.87771, 'location-v2') $sql$, (select value from fx where key = 'a')),
  'feature_disabled%', 'with the feature off nobody can opt in');
reset role;
select tests.set_flag('precise_location', true);

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(public.set_location_disclosure((select value::uuid from fx where key = 'a'), 'approximate_pin', 19.07612, 72.87771, 'location-v2')->>'mode',
  'approximate_pin', 'consent and an in-India pin are accepted');
select is(public.get_owner_profile((select value::uuid from fx where key = 'a'))->'mapLocation', '{"lat": 19.08, "lng": 72.88}'::jsonb,
  'the exact coordinate was never stored: the owner sees the rounded pin');
select is(public.get_location_settings((select value::uuid from fx where key = 'a'))->>'needsReconsent', 'false', 'settings report current consent');
reset role;
select is((select map_lat from public.provider_profiles where id = (select value::uuid from fx where key = 'a')), 19.08::double precision,
  'storage holds ~1 km precision only');
select is((select granted::text || '/' || wording_version from public.consent_records
           where provider_id = (select value::uuid from fx where key = 'a') and kind = 'show_map_location' order by recorded_at desc, id limit 1),
  'true/location-v2', 'the consent is recorded with its wording version');

-- What every public surface returns.
select tests.authenticate_as_anon();
select is(pg_temp.pin('a'), '{"lat": 19.08, "lng": 72.88}'::jsonb, 'the profile shows the approximate pin');
select is(pg_temp.pin('b'), 'null'::jsonb, 'a locality-only listing exposes no coordinates');
select is(
  (select i->'provider'->'mapLocation' from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i
   where i->'provider'->>'displayName' = 'Area Only Listing'),
  'null'::jsonb, 'search results for a locality-only listing carry no pin');
select ok(
  public.search_providers('test-active-city', 'test-locality-a')::text !~ '19\.076|72\.877|map_lat|map_lng'
  and public.providers_published_in_city('test-active-city')::text !~ '19\.076|72\.877',
  'no public list contains a coordinate finer than the approximation');
reset role;

-- Rollback switch: flag off hides every pin, consent stays.
select tests.set_flag('precise_location', false);
select tests.authenticate_as_anon();
select is(pg_temp.pin('a'), 'null'::jsonb, 'turning the flag off removes pins from public output at once');
reset role;
select tests.set_flag('precise_location', true);

-- Wording bump: an old consent is flagged for re-consent.
update public.provider_profiles set location_consent_version = 'location-v1' where id = (select value::uuid from fx where key = 'a');
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(public.get_location_settings((select value::uuid from fx where key = 'a'))->>'needsReconsent', 'true',
  'a pin consented under older wording is flagged for re-consent');

-- Opting out keeps area search and deletes the coordinates.
select is(public.set_location_disclosure((select value::uuid from fx where key = 'a'), 'locality_only')->>'hasPin', 'false', 'switching to locality-only works');
select lives_ok(format($sql$ select public.set_map_location(%L, null, null) $sql$, (select value from fx where key = 'a')), 'and the old setter can still clear');
reset role;
select is((select map_lat is null and map_lng is null and location_mode = 'locality_only' from public.provider_profiles where id = (select value::uuid from fx where key = 'a')),
  true, 'the coordinates are deleted, not just hidden');
-- recorded_at is now() for the whole test transaction, so assert existence rather than ordering.
select ok(exists(select 1 from public.consent_records where provider_id = (select value::uuid from fx where key = 'a') and kind = 'show_map_location'
           and not granted), 'the withdrawal is recorded');
select tests.authenticate_as_anon();
select is(pg_temp.pin('a'), 'null'::jsonb, 'and the profile is area-search only again');
select ok(public.search_providers('test-active-city', 'test-locality-a')::text like '%Pin Listing%', 'the listing is still found by area');
reset role;

select * from finish();
rollback;
