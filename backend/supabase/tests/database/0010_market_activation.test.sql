-- Phase 028: market activation is admin-only, audited, and every discovery
-- path honours it. Phone range +91900000100x.
begin;
select plan(13);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('admin', tests.create_admin('+919000001001')::text),
  ('owner', tests.create_phone_user('+919000001002')::text),
  ('owner_b', tests.create_phone_user('+919000001003')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000001002', 'Market Listing A')::text;
insert into fx select 'b', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner_b'), '+919000001003', 'Market Listing B')::text;
insert into public.promotions (provider_id, state, placement, starts_at, ends_at, city_id)
  values ((select value::uuid from fx where key = 'a'), 'active', 'home_featured',
          now() - interval '1 day', now() + interval '1 day', 'test-active-city');

-- Where does provider a show up for an anonymous visitor? (b is its sibling.)
create function tests.vis(p_a uuid, p_b uuid) returns jsonb language sql as $$
  select jsonb_build_object(
    'search', exists (select 1 from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i
                      where i->'provider'->>'id' = p_a::text),
    'profile', public.get_public_profile(p_a) is not null,
    'similar', exists (select 1 from jsonb_array_elements(public.similar_providers(p_b)) s where s->>'id' = p_a::text),
    'count', public.provider_count_by_locality('test-active-city') ? 'test-locality-a',
    'city', exists (select 1 from jsonb_array_elements(public.providers_published_in_city('test-active-city')) s where s->>'id' = p_a::text),
    'promos', exists (select 1 from jsonb_array_elements(public.active_promotions('test-active-city')) s where s->>'providerId' = p_a::text));
$$;
grant execute on function tests.vis(uuid, uuid) to anon, authenticated;

create temporary table expect (visible jsonb, hidden jsonb);
select tests.share_fixture('expect');
insert into expect values (
  '{"search":true,"profile":true,"similar":true,"count":true,"city":true,"promos":true}',
  '{"search":false,"profile":false,"similar":false,"count":false,"city":false,"promos":false}');

select tests.authenticate_as_anon();
select is(tests.vis((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'b')),
  (select visible from expect), 'baseline: an active-market listing is visible on every discovery path');
reset role;

-- Authorisation and validation.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  $sql$ select public.set_city_launch_status('test-active-city', 'coming_soon', 'because') $sql$,
  '%not_owner:%', 'a non-admin cannot change city activation');
select throws_like(
  $sql$ select public.set_category_launch_approval('test-category-plumbing', false, 'because') $sql$,
  '%not_owner:%', 'a non-admin cannot change category approval');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'admin'));
select throws_like(
  $sql$ select public.set_city_launch_status('test-active-city', 'coming_soon', '') $sql$,
  '%validation_failed:%', 'an empty reason is rejected');
select throws_like(
  $sql$ select public.set_city_launch_status('test-active-city', 'coming_soon', '   ') $sql$,
  '%validation_failed:%', 'a blank reason is rejected');

-- City goes coming_soon: the listing vanishes everywhere.
select public.set_city_launch_status('test-active-city', 'coming_soon', 'pause market for test');
reset role;

select tests.authenticate_as_anon();
select is(tests.vis((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'b')),
  (select hidden from expect), 'a coming_soon city hides the listing on every discovery path');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(
  (public.get_owner_profile((select value::uuid from fx where key = 'a')))->>'isPubliclyListed',
  'false', 'owner json reports isPubliclyListed=false');
select is(
  (public.get_owner_profile((select value::uuid from fx where key = 'a')))->>'displayName',
  'Market Listing A', 'the owner still gets the profile back');
reset role;

-- Back to active, then un-approve the only category.
select tests.authenticate_as((select value::uuid from fx where key = 'admin'));
select public.set_city_launch_status('test-active-city', 'active', 'reopen market for test');
reset role;
select tests.authenticate_as_anon();
select is(tests.vis((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'b')),
  (select visible from expect), 'reactivating the city restores visibility');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'admin'));
select public.set_category_launch_approval('test-category-plumbing', false, 'category not ready');
reset role;
select tests.authenticate_as_anon();
select is(tests.vis((select value::uuid from fx where key = 'a'), (select value::uuid from fx where key = 'b')),
  (select hidden from expect), 'un-approving the only category hides the listing on every discovery path');
reset role;

-- Audit evidence (read as superuser: API roles cannot see private).
select ok(
  (select count(*) from private.audit_events
   where action = 'city_launch_status_set' and target_id = 'test-active-city'
     and actor_id = (select value::uuid from fx where key = 'admin')
     and reason = 'pause market for test') = 1,
  'the city change is audited with actor and reason');
select ok(
  exists (select 1 from private.audit_events
          where action = 'category_launch_approval_set' and target_id = 'test-category-plumbing'
            and reason = 'category not ready' and details->>'to' = 'false'),
  'the category change is audited');
select ok(
  (select count(*) from private.audit_events where action = 'city_launch_status_set' and target_id = 'test-active-city') = 2,
  'both city transitions were audited');

select * from finish();
rollback;
