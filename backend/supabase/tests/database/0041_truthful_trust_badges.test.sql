-- Phase 090 (migration 0041): public badges are computed from evidence that
-- still holds. Phones +91900041xxxx.
begin;
select plan(33);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('owner', tests.create_phone_user('+919000410001')::text),
  ('other', tests.create_phone_user('+919000410002')::text),
  ('mod', tests.create_admin('+919000410003')::text),
  ('sup', tests.create_phone_user('+919000410004')::text),
  ('paused', tests.create_phone_user('+919000410005')::text);
insert into public.app_admins (user_id) select value::uuid from fx where key = 'sup';
insert into private.admin_roles (user_id, role) values ((select value::uuid from fx where key = 'sup'), 'support');
insert into fx select 'a', tests.create_published_provider((select value::uuid from fx where key = 'owner'), '+919000410001', 'Badge Listing')::text;
insert into fx select 'b', tests.create_published_provider((select value::uuid from fx where key = 'other'), '+919000410002', 'Unbadged Listing')::text;
insert into fx select 'p', tests.create_published_provider((select value::uuid from fx where key = 'paused'), '+919000410005', 'Paused Listing')::text;
update public.provider_profiles set status = 'paused' where id = (select value::uuid from fx where key = 'p');
grant all on fx to authenticated;

-- ------------------------------------------------------------- truth table
-- Helper: the public verification map for listing a, seen by a guest.
create function pg_temp.pub(p_key text default 'a') returns jsonb language sql as $$
  select public.get_public_profile((select value::uuid from fx where key = p_key))->'verification' $$;
grant execute on function pg_temp.pub(text) to anon, authenticated;

select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{}'::jsonb, 'no evidence: no badge at all');
reset role;

-- Legacy or forged rows do not count: an "approved" credentials record with no
-- attributable decision is not a badge.
insert into public.verification_records (provider_id, kind, status, method)
  values ((select value::uuid from fx where key = 'a'), 'credentials', 'approved', 'document_review');
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{}'::jsonb, 'an approved credentials row without a decision is not shown');
reset role;

insert into public.verification_records (provider_id, kind, status, method)
  values ((select value::uuid from fx where key = 'a'), 'phone', 'approved', 'otp');
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{"phone": "approved"}'::jsonb, 'phone verified shows only the phone fact');
reset role;

update auth.users set phone_confirmed_at = null where id = (select value::uuid from fx where key = 'owner');
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{}'::jsonb, 'an unconfirmed auth phone removes the phone badge even with an old record');
reset role;
update auth.users set phone_confirmed_at = now() where id = (select value::uuid from fx where key = 'owner');

insert into public.verification_records (provider_id, kind, status, method, created_at)
  values ((select value::uuid from fx where key = 'a'), 'phone', 'pending', 'otp', now() + interval '1 second');
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{}'::jsonb, 'a newer non-approved phone record removes it');
reset role;
delete from public.verification_records where provider_id = (select value::uuid from fx where key = 'a') and status = 'pending';

-- ---------------------------------------------------------- listing review
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(format($sql$ select public.review_listing(%L, 'reviewing my own listing') $sql$, (select value from fx where key = 'a')),
  'not_owner%', 'a provider cannot mark their own listing reviewed');
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'sup'));
select throws_like(format($sql$ select public.review_listing(%L, 'support is not moderation') $sql$, (select value from fx where key = 'a')),
  'not_owner%', 'only the moderation role can mark a listing reviewed');
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'mod'), 1800);
select throws_like(format($sql$ select public.review_listing(%L, 'stale mfa session') $sql$, (select value from fx where key = 'a')),
  'reauth_required%', 'and needs a recent factor proof');
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'mod'));
select throws_like(format($sql$ select public.review_listing(%L, 'paused listing') $sql$, (select value from fx where key = 'p')),
  'conflict%', 'a paused listing cannot be marked reviewed');
select lives_ok(format($sql$ select public.review_listing(%L, 'name and description read, nothing misleading') $sql$, (select value from fx where key = 'a')),
  'a moderator records a review');
reset role;
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{"phone": "approved", "listing": "approved"}'::jsonb, 'the review shows as its own fact');
reset role;

-- Editing the reviewed content takes the badge down until it is reviewed again.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(format($sql$ select public.update_profile_full(%L, '{"description":"Now offering something completely different"}') $sql$, (select value from fx where key = 'a')),
  'the owner edits the description');
reset role;
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{"phone": "approved"}'::jsonb, 'an edit after review removes the reviewed label');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'mod'));
select public.review_listing((select value::uuid from fx where key = 'a'), 'edited text re-read and acceptable');
select is(public.withdraw_listing_review((select value::uuid from fx where key = 'a'), 'complaint under investigation'), 2, 'a moderator withdraws every live review of the listing (the superseded one too)');
reset role;
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{"phone": "approved"}'::jsonb, 'a withdrawn review shows nowhere');
reset role;

select tests.authenticate_as_admin((select value::uuid from fx where key = 'mod'));
select public.review_listing((select value::uuid from fx where key = 'a'), 'third review, acceptable');
reset role;
update private.listing_reviews set valid_until = current_date - 1 where withdrawn_at is null;
select tests.authenticate_as_anon();
select is(pg_temp.pub(), '{"phone": "approved"}'::jsonb, 'an expired review shows nowhere');
reset role;

-- Every public surface agrees.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'mod'));
select public.review_listing((select value::uuid from fx where key = 'a'), 'fourth review, acceptable');
reset role;
select tests.authenticate_as_anon();
select is(
  (select i->'provider'->'verification' from jsonb_array_elements(public.search_providers('test-active-city', 'test-locality-a')->'items') i
   where i->'provider'->>'displayName' = 'Badge Listing'),
  '{"phone": "approved", "listing": "approved"}'::jsonb, 'search returns the same badges as the profile');
select is(
  (select count(*)::int from jsonb_array_elements(public.providers_published_in_city('test-active-city')) p
   where p->'verification' ? 'listing'), 1, 'and so does the city list');
reset role;

-- Suspension ends it (and the listing).
select tests.moderate_as_admin((select value::uuid from fx where key = 'a'), 'suspended', 'test suspension');
select tests.authenticate_as_anon();
select is(public.get_trust_summary((select value::uuid from fx where key = 'a')), null, 'a suspended listing has no public trust summary');
reset role;
select tests.moderate_as_admin((select value::uuid from fx where key = 'a'), 'active', null);

-- ---------------------------------------------------- client cannot confer
select tests.authenticate_as((select value::uuid from fx where key = 'other'));
select lives_ok(format($sql$ select public.update_profile_full(%L, '{"verification":{"phone":"approved","credentials":"approved"},"isVerified":true,"phoneVerified":true,"trusted":true}') $sql$, (select value from fx where key = 'b')),
  'a client payload full of verification flags is accepted as ordinary (ignored) input');
select throws_ok(format($sql$ insert into public.verification_records (provider_id, kind, status) values (%L, 'phone', 'approved') $sql$, (select value from fx where key = 'b')),
  '42501', null, 'a provider cannot write verification records');
select throws_ok(format($sql$ update public.provider_profiles set display_name = 'x', location_mode = 'approximate_pin' where id = %L $sql$, (select value from fx where key = 'b')),
  '42501', null, 'nor update profile columns directly');
reset role;
select tests.authenticate_as_anon();
select is(pg_temp.pub('b'), '{}'::jsonb, 'so the unreviewed listing still has no badge');
reset role;

-- ------------------------------------------------------ localized wording
select tests.authenticate_as_anon();
select is(
  (select jsonb_agg(b->>'key') from jsonb_array_elements(public.get_trust_summary((select value::uuid from fx where key = 'a'))->'badges') b),
  '["phone_verified", "listing_reviewed"]'::jsonb, 'the summary lists only the facts that are currently true, in a fixed order');
select is(public.get_trust_summary((select value::uuid from fx where key = 'a'), 'hi-IN')->>'locale', 'hi', 'locale hi-IN resolves to hi');
select is(public.get_trust_summary((select value::uuid from fx where key = 'a'), 'fr')->>'locale', 'en', 'an unsupported locale falls back to English');
select isnt(
  public.get_trust_summary((select value::uuid from fx where key = 'a'), 'mr')->'badges'->0->>'label',
  public.get_trust_summary((select value::uuid from fx where key = 'a'), 'en')->'badges'->0->>'label', 'Marathi text differs from English');
select ok(
  public.get_trust_summary((select value::uuid from fx where key = 'a'), 'en')->'selfReported'->>'scope' like '%written by the provider%',
  'provider-written fields are labelled as such');
select ok(
  jsonb_array_length(public.get_trust_summary((select value::uuid from fx where key = 'a'))->'selfReportedFields') >= 5,
  'and the summary says which public fields they are');
select is(public.get_trust_summary((select value::uuid from fx where key = 'p')), null, 'a paused listing has no public summary');
select throws_ok($$ insert into public.trust_copy values ('self_reported', 'en', 'x', 'y', 'z') $$, '42501', null, 'the wording table is read-only');
reset role;
select is((select string_agg(locale || ':' || n, ',' order by locale) from (select locale, count(*) n from public.trust_copy group by locale) t),
  'en:4,hi:4,mr:4', 'every badge has wording in every supported language');
select is((select count(*)::int from public.trust_copy where label ~* '(trusted|safe|guarantee|certified)' or scope ~* '(trusted|safe|guarantee|certified)'),
  0, 'no label or scope claims a universal guarantee');

select * from finish();
rollback;
