-- Phase 086 (migration 0035): derivative set and byte budgets. Phones: none needed.
-- Measured browsing on real devices/CDN is NOT done here (no hosted project, no
-- device lab); this pins the declared budget and that DB and encoder share it.
begin;
select plan(6);

set local role service_role;
select is(jsonb_array_length(public.media_policy()->'derivatives'), 2, 'exactly two derivatives exist: no speculative variants');
select is((public.media_policy()->'derivatives'->0)->>'kind', 'thumb', 'the card derivative is listed first');
select is(((public.media_policy()->'derivatives'->0)->>'maxEdge')::int, 320, 'cards never need more than 320 px');
select ok(((public.media_policy()->>'cardPageSize')::int * ((public.media_policy()->'derivatives'->0)->>'maxBytes')::int) <= 20 * 40 * 1024,
  'a results page of cards loads at most 800 KB of media (thumbs only)');
select is((public.media_policy()->>'maxPhotos')::int, 5, 'the photo limit is a server setting, currently 5');
reset role;
select tests.authenticate_as_anon();
select throws_ok($$ select public.media_policy() $$, '42501', null, 'the policy is not an anon-callable function');
reset role;

select * from finish();
rollback;
