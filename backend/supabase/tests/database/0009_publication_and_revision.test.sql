-- Phases 027/030/032: publication invariants, consent withdrawal, revisions.
-- Phone range +91900000090x.
begin;
select plan(12);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('owner', tests.create_phone_user('+919000000901')::text),
  ('nocons', tests.create_phone_user('+919000000902')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000000901', 'Revision Listing')::text;

-- A draft listing whose owner has NOT consented to showing their number.
insert into public.provider_profiles (user_id, phone_e164, display_name, base_city_id, base_locality_id,
                                      phone_display_consented, status)
  values ((select value::uuid from fx where key = 'nocons'), '+919000000902', 'No Consent', 'test-active-city',
          'test-locality-a', false, 'draft');
insert into fx select 'draft', id::text from public.provider_profiles
  where user_id = (select value::uuid from fx where key = 'nocons');
insert into public.provider_categories (provider_id, category_id)
  values ((select value::uuid from fx where key = 'draft'), 'test-category-plumbing');
insert into public.provider_service_areas (provider_id, city_id, locality_id, is_primary)
  values ((select value::uuid from fx where key = 'draft'), 'test-active-city', 'test-locality-a', true);

-- Publishing a draft without phone display consent is refused (not silently
-- downgraded to paused -- that only applies to already-published listings).
select tests.authenticate_as((select value::uuid from fx where key = 'nocons'));
select throws_like(
  format($sql$ select public.set_listing_status(%L::uuid, 'published') $sql$, (select value from fx where key = 'draft')),
  '%listing_not_publishable:%',
  'publishing without phone display consent is refused');
reset role;

-- WhatsApp on while consented, then consent withdrawn on a published listing.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select lives_ok(
  format($sql$ select public.record_consent(%L::uuid, 'whatsapp_contact', true) $sql$, (select value from fx where key = 'a')),
  'whatsapp can be enabled while phone consent is on');
select public.record_consent((select value::uuid from fx where key = 'a'), 'display_phone_number', false);
reset role;

select is(
  (select status::text from public.provider_profiles where id = (select value::uuid from fx where key = 'a')),
  'paused', 'withdrawing phone consent pauses the published listing');
select is(
  (select whatsapp_enabled from public.provider_profiles where id = (select value::uuid from fx where key = 'a')),
  false, 'withdrawing phone consent switches whatsapp off');
select ok(
  exists (select 1 from public.consent_records
          where provider_id = (select value::uuid from fx where key = 'a')
            and kind = 'display_phone_number' and granted = false and withdrawn_at is not null),
  'the withdrawal is recorded with granted=false and withdrawn_at');

select tests.authenticate_as_anon();
select is(public.get_public_profile((select value::uuid from fx where key = 'a')), null::jsonb,
  'get_public_profile returns null after withdrawal');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.record_consent(%L::uuid, 'whatsapp_contact', true) $sql$, (select value from fx where key = 'a')),
  '%consent_required:%', 'whatsapp cannot be granted while phone consent is off');

-- Optimistic revisions.
create temporary table rev (r bigint);
select tests.share_fixture('rev');
insert into rev select revision from public.provider_profiles where id = (select value::uuid from fx where key = 'a');
select throws_like(
  format($sql$ select public.update_profile_full(%L::uuid, jsonb_build_object('displayName', 'Stale', 'expectedRevision', %s)) $sql$,
         (select value from fx where key = 'a'), (select r - 1 from rev)),
  '%conflict: revision_mismatch%', 'a stale expectedRevision is a conflict');
select lives_ok(
  format($sql$ select public.update_profile_full(%L::uuid, jsonb_build_object('displayName', 'Fresh', 'expectedRevision', %s)) $sql$,
         (select value from fx where key = 'a'), (select r from rev)),
  'the current expectedRevision succeeds');
reset role;
select ok(
  (select revision from public.provider_profiles where id = (select value::uuid from fx where key = 'a')) > (select r from rev),
  'the revision increments after a successful update');

-- The row trigger refuses owner changes to moderation and ownership even
-- when the grant layer is bypassed (superuser carrying the owner's claims).
select set_config('request.jwt.claims',
  json_build_object('sub', (select value from fx where key = 'owner'), 'role', 'authenticated')::text, true);
select throws_like(
  format($sql$ update public.provider_profiles set moderation_status = 'suspended' where id = %L $sql$, (select value from fx where key = 'a')),
  '%not_owner:%', 'a non-admin cannot change moderation_status');
select throws_like(
  format($sql$ update public.provider_profiles set user_id = %L where id = %L $sql$,
         (select value from fx where key = 'nocons'), (select value from fx where key = 'a')),
  '%not_owner:%', 'a listing cannot change owner');

select * from finish();
rollback;
