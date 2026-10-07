-- Phase 033: guest submissions through bounded, rate-limited RPCs.
-- Phone range +91900000110x.
begin;
select plan(17);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('u1', tests.create_phone_user('+919000001101')::text),
  ('u2', tests.create_phone_user('+919000001102')::text),
  ('u3', tests.create_phone_user('+919000001103')::text),
  ('u4', tests.create_phone_user('+919000001104')::text),
  ('u5', tests.create_phone_user('+919000001105')::text),
  ('u6', tests.create_phone_user('+919000001106')::text);
insert into fx select 'p1', tests.create_published_provider((select value::uuid from fx where key = 'u1'), '+919000001101', 'Guest P1')::text;
insert into fx select 'p2', tests.create_published_provider((select value::uuid from fx where key = 'u2'), '+919000001102', 'Guest P2')::text;
insert into fx select 'p3', tests.create_published_provider((select value::uuid from fx where key = 'u3'), '+919000001103', 'Guest P3')::text;
insert into fx select 'p4', tests.create_published_provider((select value::uuid from fx where key = 'u4'), '+919000001104', 'Guest P4')::text;
insert into fx select 'p5', tests.create_published_provider((select value::uuid from fx where key = 'u5'), '+919000001105', 'Guest P5')::text;
insert into fx select 'p6', tests.create_published_provider((select value::uuid from fx where key = 'u6'), '+919000001106', 'Guest P6')::text;
update public.provider_profiles set status = 'paused' where id = (select value::uuid from fx where key = 'p6');

-- Guest identity is the edge-provided client IP.
select set_config('request.headers', '{"cf-connecting-ip":"203.0.113.7"}', true);
select tests.authenticate_as_anon();

insert into fx select 'r1', public.submit_report((select value::uuid from fx where key = 'p1'), 'wrong_phone_number', 'rings elsewhere')->>'receiptId';
select ok((select value from fx where key = 'r1') is not null, 'anon submit_report on a listed provider returns a receiptId');

select is(
  public.submit_report((select value::uuid from fx where key = 'p1'), 'other', 'again')->>'receiptId',
  (select value from fx where key = 'r1'),
  'a repeat from the same source within 24h returns the same receiptId');
reset role;
select is(
  (select count(*)::int from public.reports where provider_id = (select value::uuid from fx where key = 'p1')),
  1, 'the repeat did not create a second row');

select tests.authenticate_as_anon();
select throws_like(
  format($sql$ select public.submit_report(%L::uuid, 'other', %L) $sql$, (select value from fx where key = 'p2'), repeat('x', 1001)),
  '%validation_failed:%', 'details over 1000 characters are rejected');
select throws_like(
  $sql$ select public.submit_report('00000000-0000-0000-0000-00000000dead', 'other', 'x') $sql$,
  '%not_found:%', 'a report on an unknown provider is not_found');
select throws_like(
  format($sql$ select public.submit_report(%L::uuid, 'other', 'x') $sql$, (select value from fx where key = 'p6')),
  '%not_found:%', 'a report on an unlisted (paused) provider is not_found');

-- Reports 2..5 use up the hourly budget of 5 for this source; the 6th is refused.
select public.submit_report((select value::uuid from fx where key = 'p2'), 'other');
select public.submit_report((select value::uuid from fx where key = 'p3'), 'other');
select public.submit_report((select value::uuid from fx where key = 'p4'), 'other');
select public.submit_report((select value::uuid from fx where key = 'p5'), 'other');
reset role;
-- p6 is paused; make it listed again as the sixth distinct target.
update public.provider_profiles set status = 'published' where id = (select value::uuid from fx where key = 'p6');
select tests.authenticate_as_anon();
select throws_like(
  format($sql$ select public.submit_report(%L::uuid, 'other') $sql$, (select value from fx where key = 'p6')),
  '%rate_limited:%', 'the 6th distinct report from one source within an hour is rate limited');

-- No direct writes.
select throws_ok(
  format($sql$ insert into public.reports (provider_id, reason) values (%L, 'other') $sql$, (select value from fx where key = 'p1')),
  '42501', null, 'anon cannot insert into reports directly');
select throws_ok(
  format($sql$ insert into public.engagement_events (provider_id, type) values (%L, 'profile_view') $sql$, (select value from fx where key = 'p1')),
  '42501', null, 'anon cannot insert into engagement_events directly');
select throws_ok(
  $sql$ insert into public.city_requests (city_name) values ('Nowhere') $sql$,
  '42501', null, 'anon cannot insert into city_requests directly');

-- Engagement: capped at 10 per provider+type per hour, never raises.
select set_config('request.headers', '{"cf-connecting-ip":"203.0.113.8"}', true);
select lives_ok(
  format($sql$ select public.record_engagement(%L::uuid, 'profile_view') from generate_series(1, 12) $sql$, (select value from fx where key = 'p1')),
  'record_engagement never raises when over budget');
reset role;
select is(
  (select count(*)::int from public.engagement_events
   where provider_id = (select value::uuid from fx where key = 'p1') and type = 'profile_view'),
  10, 'at most 10 engagement rows are stored per provider and type per hour');

-- City requests.
select tests.authenticate_as_anon();
select set_config('request.headers', '{"cf-connecting-ip":"203.0.113.9"}', true);
select public.request_city('Guest Town', 'Maharashtra', 'please');
reset role;
select is(
  (select submitted_by_phone from public.city_requests where city_name = 'Guest Town'),
  null, 'request_city stores submitted_by_phone null for anon');

select tests.authenticate_as((select value::uuid from fx where key = 'u1'));
select public.request_city('Provider Town');
reset role;
select is(
  (select submitted_by_phone from public.city_requests where city_name = 'Provider Town'),
  '+919000001101', 'a signed-in provider''s request carries their own phone');

select tests.authenticate_as_anon();
select throws_like($sql$ select public.request_city('X') $sql$, '%validation_failed:%', 'a 1-character city name is rejected');
select throws_like(format($sql$ select public.request_city('Okay Town', null, %L) $sql$, repeat('n', 501)),
  '%validation_failed:%', 'a note over 500 characters is rejected');
select throws_like(format($sql$ select public.request_city('Okay Town', %L) $sql$, repeat('s', 81)),
  '%validation_failed:%', 'a state name over 80 characters is rejected');
reset role;

select * from finish();
rollback;
