-- Phase 052 (migration 0025): verified phone change. Phones +91900019xxxx.
-- The auth.users updates imitate exactly what GoTrue writes: first
-- phone_change/phone_change_sent_at (code sent to the new number), then
-- phone/phone_confirmed_at after the code is verified.
begin;
select plan(16);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('a', tests.create_phone_user('+919000190001')::text),
  ('b', tests.create_phone_user('+919000190002')::text);
insert into fx select 'pa', tests.create_published_provider((select value::uuid from fx where key = 'a'), '+919000190001', 'Change Listing A')::text;
insert into fx select 'pb', tests.create_published_provider((select value::uuid from fx where key = 'b'), '+919000190002', 'Change Listing B')::text;

-- Interrupted change: the request alone moves nothing.
select tests.allow_sensitive_action((select value::uuid from fx where key = 'a'), 'phone_change');
update auth.users set phone_change = '+919000190003', phone_change_sent_at = now()
  where id = (select value::uuid from fx where key = 'a');
select is((select phone_e164 from public.provider_profiles where id = (select value::uuid from fx where key = 'pa')),
  '+919000190001', 'an unconfirmed change leaves the profile on the original number');
select is((select status::text from public.provider_profiles where id = (select value::uuid from fx where key = 'pa')),
  'published', 'and the listing stays published');

-- Conflict: a number owned by another account is refused by Auth (unique phone).
select throws_ok(
  format($sql$ update auth.users set phone = '+919000190002', phone_confirmed_at = now() where id = %L $sql$,
    (select value from fx where key = 'a')),
  '23505', null, 'a number that belongs to another account cannot be taken');
select is((select user_id::text from public.provider_profiles where id = (select value::uuid from fx where key = 'pb')),
  (select value from fx where key = 'b'), 'the other account keeps its profile');
select is((select phone_e164 from public.provider_profiles where id = (select value::uuid from fx where key = 'pa')),
  '+919000190001', 'and the failed attempt left A untouched');

-- Commit: code verified for the new number.
update auth.users set phone = '+919000190003', phone_change = '', phone_confirmed_at = now()
  where id = (select value::uuid from fx where key = 'a');
select is((select user_id::text from public.provider_profiles where phone_e164 = '+919000190003'),
  (select value from fx where key = 'a'), 'the profile follows the verified number and keeps its owner');
select is((select id::text from public.provider_profiles where phone_e164 = '+919000190003'),
  (select value from fx where key = 'pa'), 'it is the same profile row');
select is((select phone_display_consented from public.provider_profiles where id = (select value::uuid from fx where key = 'pa')),
  false, 'display consent does not carry over to the new number');
select is((select status::text from public.provider_profiles where id = (select value::uuid from fx where key = 'pa')),
  'paused', 'so a published listing is paused, not silently left public');
select is((select count(*)::int from public.consent_records
           where provider_id = (select value::uuid from fx where key = 'pa')
             and phone_e164 = '+919000190003' and granted = false),
  2, 'a consent row per kind records the new number as not yet consented');
select is((select count(*)::int from private.audit_events where action = 'phone_changed'
             and target_id = (select value from fx where key = 'a')),
  1, 'the change is audited once');
select is((select count(*)::int from private.audit_events
           where action = 'phone_changed' and (details::text ~ '\d{8,}' or coalesce(reason, '') ~ '\d{8,}')),
  0, 'the audit record contains no phone number');
select is((select count(*)::int from public.verification_records
           where provider_id = (select value::uuid from fx where key = 'pa') and kind = 'phone' and status = 'approved'),
  1, 'phone verification is recorded for the new number');

-- A number still recorded on a stale profile cannot be claimed through a change:
-- the profile uniqueness error rolls back the whole change, auth.users included.
insert into fx values ('d', tests.create_phone_user('+919000190010')::text);
insert into fx select 'pd', tests.create_published_provider((select value::uuid from fx where key = 'd'), '+919000190010', 'Stale Holder')::text;
update auth.users set phone = null, phone_confirmed_at = null where id = (select value::uuid from fx where key = 'd');
select throws_ok(
  format($sql$ update auth.users set phone = '+919000190010', phone_confirmed_at = now() where id = %L $sql$,
    (select value from fx where key = 'b')),
  '23505', null, 'a number held by another profile cannot be claimed (unique), and nothing is half-applied');
select is((select phone from auth.users where id = (select value::uuid from fx where key = 'b')),
  '+919000190002', 'B keeps the original verified number after the failed change');

-- E.164 on the remaining phone columns.
select throws_ok(
  format($sql$ insert into public.consent_records (provider_id, kind, granted, phone_e164) values (%L, 'public_profile', true, '98765') $sql$,
    (select value from fx where key = 'pa')),
  '23514', null, 'consent rows must carry E.164');

select * from finish();
rollback;
