begin;
select plan(4);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
insert into fx values ('owner', tests.create_phone_user('+919000000041')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000000041', 'Visible Provider'
)::text;

-- Public search results never include moderation internals.
select ok(
  not (
    (select i->'provider' from jsonb_array_elements(
       public.search_providers('test-active-city', 'test-locality-a')->'items'
     ) i where i->'provider'->>'id' = (select value from fx where key = 'a')) ? 'moderationStatus'
  ),
  'search results omit moderationStatus from the public provider shape'
);

-- get_public_profile() omits it too, for the same provider viewed directly.
select ok(
  not (public.get_public_profile((select value::uuid from fx where key = 'a')) ? 'moderationStatus'),
  'get_public_profile omits moderationStatus'
);

-- Anon cannot read the raw provider_profiles table row at all for a listing
-- that is NOT published+active (draft, in this case) -- the "public" RLS
-- branch only matches published+active rows, and anon owns nothing.
insert into fx values ('draft_owner', tests.create_phone_user('+919000000042')::text);
insert into public.provider_profiles (user_id, phone_e164, display_name, base_city_id, base_locality_id, moderation_status, suspension_reason)
  values ((select value::uuid from fx where key = 'draft_owner'), '+919000000042', 'Draft Provider', 'test-active-city', 'test-locality-a', 'suspended', 'secret internal note');

select tests.authenticate_as_anon();
-- Since 0013 anon has no grant on provider_profiles at all: public discovery
-- is RPC-only, so no row (published or not) is readable directly.
select throws_ok(
  $sql$ select 1 from public.provider_profiles where phone_e164 = '+919000000042' $sql$,
  '42501', null,
  'anon cannot read provider_profiles directly, so no internals are reachable'
);
reset role;

-- And get_public_profile() returns null for it too (status is draft, not
-- published), so a stale/guessed id can never surface moderation details.
select is(
  public.get_public_profile((select id from public.provider_profiles where phone_e164 = '+919000000042')),
  null,
  'get_public_profile returns null for a non-published listing, never its internals'
);

select * from finish();
rollback;
