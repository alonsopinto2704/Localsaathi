-- Phase 022: the public JSON is an allowlist. Phone range +91900000070x.
begin;
select plan(9);
select tests.ensure_reference_data();
select tests.set_flag('precise_location', true);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('owner', tests.create_phone_user('+919000000701')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000000701', 'Projection Listing')::text;

update public.provider_profiles set map_lat = 19.07612, map_lng = 72.87771
  where id = (select value::uuid from fx where key = 'a');

-- Rejected credential: present in the owner view, absent from the public one.
insert into public.credential_records (provider_id, title)
  values ((select value::uuid from fx where key = 'a'), 'Council registration');
insert into public.verification_records (provider_id, kind, status, method)
  values ((select value::uuid from fx where key = 'a'), 'credentials', 'rejected', 'document_review');

create temporary table expected_keys (k text primary key);
select tests.share_fixture('expected_keys');
insert into expected_keys values
  ('id'), ('displayName'), ('baseCityId'), ('baseLocalityId'), ('status'), ('createdAt'), ('updatedAt'),
  ('phoneE164'), ('phoneDisplayConsented'), ('whatsappEnabled'), ('categoryIds'), ('serviceAreas'),
  ('description'), ('languages'), ('workingHours'), ('photos'), ('startingPrices'), ('healthcareDetails'),
  ('homeVisits'), ('availability'), ('verification'), ('pinCodes'), ('mapLocation');

select tests.authenticate_as_anon();
select set_eq(
  format($$ select jsonb_object_keys(public.get_public_profile(%L::uuid)) $$, (select value from fx where key = 'a')),
  $$ select k from expected_keys $$,
  'get_public_profile returns exactly the allowlisted keys'
);

select ok(
  not (public.get_public_profile((select value::uuid from fx where key = 'a')) ?| array['user_id', 'userId', 'moderationStatus', 'revision', 'isPubliclyListed']),
  'public profile has no user_id / moderationStatus / revision / isPubliclyListed'
);

select is(
  public.get_public_profile((select value::uuid from fx where key = 'a'))->'mapLocation',
  '{"lat": 19.08, "lng": 72.88}'::jsonb,
  'public mapLocation is rounded to 2 decimals'
);

select ok(
  not (public.get_public_profile((select value::uuid from fx where key = 'a'))->'verification' ? 'credentials'),
  'a rejected credential is omitted from the public verification map'
);
reset role;

-- A new column on the table must not leak into public output.
alter table public.provider_profiles add column secret_note text default 'x';
select tests.authenticate_as_anon();
select set_eq(
  format($$ select jsonb_object_keys(public.get_public_profile(%L::uuid)) $$, (select value from fx where key = 'a')),
  $$ select k from expected_keys $$,
  'adding a column to provider_profiles does not change the public key set'
);
select set_eq(
  $$ select jsonb_object_keys(i->'provider')
     from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i $$,
  $$ select k from expected_keys $$,
  'search results use the same allowlisted key set'
);
select ok(
  public.search_providers('test-active-city', 'test-locality-a')::text not like '%secret_note%',
  'secret_note is absent from search results'
);
reset role;

-- Owner view.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(
  public.get_owner_profile((select value::uuid from fx where key = 'a'))->'verification'->>'credentials',
  'rejected', 'the owner still sees the rejected credential'
);
select is(
  public.get_owner_profile((select value::uuid from fx where key = 'a'))->'mapLocation',
  '{"lat": 19.07612, "lng": 72.87771}'::jsonb,
  'owner mapLocation is exact'
);
reset role;

select * from finish();
rollback;
