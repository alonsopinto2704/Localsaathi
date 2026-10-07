begin;
select plan(3);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('owner', tests.create_phone_user('+919000000011')::text),
  ('intruder', tests.create_phone_user('+919000000012')::text);

insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000000011', 'Owned Listing'
)::text;

-- A provider based in locality B but who also serves locality A must still
-- be found by a customer searching locality A ("providers being found
-- through service areas", not just their base address).
insert into fx values ('server_b', tests.create_phone_user('+919000000013')::text);
insert into fx select 'b', tests.create_published_provider(
  (select value::uuid from fx where key = 'server_b'), '+919000000013', 'Serves Locality A From B',
  'test-active-city', 'test-locality-b', 'test-locality-a'
)::text;

-- A suspended listing and a paused listing, both otherwise well-formed.
insert into fx values ('suspended_user', tests.create_phone_user('+919000000014')::text);
insert into fx select 'suspended', tests.create_published_provider(
  (select value::uuid from fx where key = 'suspended_user'), '+919000000014', 'Suspended Listing'
)::text;
select tests.moderate_as_admin((select value::uuid from fx where key = 'suspended'), 'suspended', 'test');

insert into fx values ('paused_user', tests.create_phone_user('+919000000015')::text);
insert into fx select 'paused', tests.create_published_provider(
  (select value::uuid from fx where key = 'paused_user'), '+919000000015', 'Paused Listing'
)::text;
update public.provider_profiles set status = 'paused' where id = (select value::uuid from fx where key = 'paused');

-- ---------------------------------------------------------------------------
-- Unauthorized edits are rejected. Since migration 0013 clients have no
-- direct UPDATE grant on provider_profiles at all (writes go through owner-
-- checked RPCs), so a non-owner's direct update is refused outright rather
-- than silently matching zero rows under RLS.
select tests.authenticate_as((select value::uuid from fx where key = 'intruder'));
select throws_ok(
  format($sql$ update public.provider_profiles set display_name = 'Hijacked' where id = %L $sql$,
         (select value from fx where key = 'a')),
  '42501', null,
  'a non-owner cannot update another provider''s row directly'
);
reset role;

-- ---------------------------------------------------------------------------
-- Suspended and paused profiles are excluded from public search.
select tests.authenticate_as_anon();
select ok(
  not exists (
    select 1 from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i
    where i->'provider'->>'id' in (
      (select value from fx where key = 'suspended'),
      (select value from fx where key = 'paused')
    )
  ),
  'suspended and paused listings never appear in public search results'
);

-- ---------------------------------------------------------------------------
-- Service-area discovery: provider B (based in locality B) is found when
-- searching locality A, because it declared locality A as a service area.
select ok(
  exists (
    select 1 from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i
    where i->'provider'->>'id' = (select value from fx where key = 'b')
  ),
  'a provider is found through a declared service area, not only their base locality'
);
reset role;

select * from finish();
rollback;
