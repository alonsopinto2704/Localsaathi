begin;
select plan(4);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('registrant', tests.create_phone_user('+919000000031')::text);

select tests.authenticate_as((select value::uuid from fx where key = 'registrant'));

-- Inactive (here: coming-soon) cities reject new public listings. The
-- current mock implementation does not enforce this (see
-- docs/claude-handoff.md); the backend does, per the interface's own
-- documented contract.
select throws_like(
  format(
    $sql$ select public.register_profile(%L::jsonb) $sql$,
    json_build_object(
      'displayName', 'Should Not Register',
      'baseCityId', 'test-coming-soon-city',
      'baseLocalityId', 'test-locality-c-other-city',
      'categoryIds', jsonb_build_array('test-category-plumbing'),
      'serviceAreaIds', jsonb_build_array('test-locality-c-other-city')
    )::text
  ),
  '%location_not_active%',
  'registering a profile in a non-active city is rejected'
);

-- The same registrant succeeds once pointed at the active city.
select lives_ok(
  format(
    $sql$ select public.register_profile(%L::jsonb) $sql$,
    json_build_object(
      'displayName', 'Should Register',
      'baseCityId', 'test-active-city',
      'baseLocalityId', 'test-locality-a',
      'phoneDisplayConsented', true,
      'categoryIds', jsonb_build_array('test-category-plumbing'),
      'serviceAreaIds', jsonb_build_array('test-locality-a')
    )::text
  ),
  'registering a profile in an active city succeeds'
);

reset role;

-- Deleting the listing removes it from public search immediately.
update public.provider_profiles set status = 'published'
  where user_id = (select value::uuid from fx where key = 'registrant');

select ok(
  exists (
    select 1 from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i
    where i->'provider'->>'displayName' = 'Should Register'
  ),
  'the newly published listing is visible before deletion'
);

delete from public.provider_profiles
  where user_id = (select value::uuid from fx where key = 'registrant');

select ok(
  not exists (
    select 1 from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i
    where i->'provider'->>'displayName' = 'Should Register'
  ),
  'deleting the listing removes its public visibility immediately'
);

select * from finish();
rollback;
