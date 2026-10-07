-- Regressions for migration 0023 (2026-10-07 re-audit). Phone range +91900000170x.
begin;
select plan(8);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('owner', tests.create_phone_user('+919000001701')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000001701', 'Followup2 Listing')::text;

-- Sponsor boost obeys sponsored_placement.
insert into public.promotions (provider_id, placement, state, starts_at, ends_at, priority)
  select (select value::uuid from fx where key = 'a'), 'search_top', 'active', now() - interval '1 day', now() + interval '1 day', 5;
select tests.set_flag('sponsored_placement', false);
select tests.authenticate_as_anon();
select is(
  (select bool_or((i->>'isSponsored')::boolean) from jsonb_array_elements(
     public.search_providers('test-active-city', 'test-locality-a', '', '{}', '{}', false, false, 20, 0)->'items') i),
  false, 'flag off: nothing is sponsored in search');
reset role;
select tests.set_flag('sponsored_placement', true);
select tests.authenticate_as_anon();
select is(
  (select bool_or((i->>'isSponsored')::boolean) from jsonb_array_elements(
     public.search_providers('test-active-city', 'test-locality-a', '', '{}', '{}', false, false, 20, 0)->'items') i),
  true, 'flag on: the promoted listing is sponsored');
reset role;

-- precise_location hides the public pin when off.
update public.provider_profiles set map_lat = 19.07612, map_lng = 72.87771
  where id = (select value::uuid from fx where key = 'a');
select tests.set_flag('precise_location', false);
select tests.authenticate_as_anon();
select is(public.get_public_profile((select value::uuid from fx where key = 'a'))->'mapLocation',
  'null'::jsonb, 'precise_location off: no public pin');
reset role;

-- Validation holes.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, '{"startingPrices":[{"categoryId":"test-category-electrical","amount":500}]}') $sql$,
         (select value from fx where key = 'a')),
  'validation_failed%', 'starting price for a category the listing does not offer is refused');
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, '{"serviceAreas":[{"cityId":"x","localityId":"y","pinCodes":["abcdef999"]}]}') $sql$,
         (select value from fx where key = 'a')),
  'validation_failed%', 'service area pin codes are validated');
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, jsonb_build_object('languages', jsonb_build_array(repeat('x', 41)))) $sql$,
         (select value from fx where key = 'a')),
  'validation_failed%', 'language length is capped');
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, '{"healthcareDetails":{"specialty":"x"}}') $sql$,
         (select value from fx where key = 'a')),
  'feature_disabled%', 'healthcare writes need healthcare_listings');
reset role;

-- Audit regex now matches 8-digit E.164 too.
select throws_like($sql$ select private.write_audit('t', 't', '1', 'call +12345678', '{}') $sql$,
  'audit_redaction%', '8-digit E.164 numbers are redacted-or-refused');

select * from finish();
rollback;
