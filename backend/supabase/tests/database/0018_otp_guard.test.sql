-- Phases 042/047/048 (migration 0024). Phone range +91900001800x for users;
-- the gate itself only ever sees synthetic numbers in +9190001xxxxx / +9190002xxxxx.
begin;
select plan(24);
select tests.ensure_reference_data();

-- 042: server definition of a supported mobile number.
select is(private.is_supported_mobile('+919000012345'), true, 'valid +91 mobile');
select is(private.is_supported_mobile('+915000012345'), false, 'first digit 5 is not a mobile');
select is(private.is_supported_mobile('+91900001234'), false, 'nine digits');
select is(private.is_supported_mobile('+9190000123456'), false, 'eleven digits');
select is(private.is_supported_mobile('+12025550100'), false, 'other country');
select is(private.is_supported_mobile('919000012345'), false, 'no plus: callers normalise first');
select is(private.is_supported_mobile(null), false, 'null');

-- 047: per-number limit (3 per hour), with recovery once the window passes.
create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');

select is(
  (select array_agg((public.otp_send_gate('+919000100001', timestamptz '2026-10-07 10:00+00' + (i || ' minutes')::interval)->>'allowed')::boolean order by i)
   from generate_series(0, 3) i),
  array[true, true, true, false],
  'fourth code to one number inside an hour is refused');
select is(
  (public.otp_send_gate('+919000100001', timestamptz '2026-10-07 10:04+00')->>'reason'),
  'number_limit', 'the reason is the number limit');
select ok(
  (public.otp_send_gate('+919000100001', timestamptz '2026-10-07 10:04+00')->>'retryAfterSeconds')::int between 1 and 3600,
  'a retry-after in seconds is returned');
select is(
  (public.otp_send_gate('+919000100001', timestamptz '2026-10-07 11:01+00')->>'allowed')::boolean,
  true, 'the legitimate owner recovers once the hour has passed');

-- Daily ceiling: 8 per 24 h even when spaced out.
select is(
  (select count(*)::int from generate_series(0, 11) i
   where (public.otp_send_gate('+919000100002', timestamptz '2026-10-08 00:00+00' + (i * 90 || ' minutes')::interval)->>'allowed')::boolean),
  8, 'at most 8 codes per number per 24 hours');

-- Block (sequential-range) limit: 30 per hour across one 10,000-number block,
-- while an unrelated block is unaffected (a shared office network elsewhere).
select is(
  (select count(*)::int from generate_series(1, 35) i
   where (public.otp_send_gate('+91900020' || lpad(i::text, 4, '0'), timestamptz '2026-10-09 10:00+00')->>'allowed')::boolean),
  30, 'one number block gets at most 30 codes per hour');
select is(
  (public.otp_send_gate('+919000300001', timestamptz '2026-10-09 10:00+00')->>'allowed')::boolean,
  true, 'a number in another block is still served');
select is(
  (public.otp_send_gate('+919000200777', timestamptz '2026-10-09 10:00+00')->>'reason'),
  'block_limit', 'a further number in the saturated block is refused as block_limit');

-- Global circuit breaker.
update private.otp_limits set value = 5 where key = 'global_hour';
select is(
  (select count(*)::int from generate_series(1, 8) i
   where (public.otp_send_gate('+91900040' || lpad((i * 1000)::text, 4, '0'), timestamptz '2026-10-10 10:00+00')->>'allowed')::boolean),
  5, 'global hourly budget stops at its limit');
select is(
  (public.otp_send_gate('+919000500001', timestamptz '2026-10-10 10:01+00')->>'reason'),
  'service_paused', 'the breaker is open for everyone');
select is(
  (select count(*)::int from private.audit_events where action = 'otp_breaker_opened'),
  1, 'opening the breaker is audited once');
select is(
  (public.otp_send_gate('+919000500001', timestamptz '2026-10-10 11:05+00')->>'allowed')::boolean,
  true, 'sending resumes after the breaker period');
select public.otp_breaker_reset();
select is((select breaker_open_until is null from private.otp_settings), true, 'an operator can reset the breaker');

-- 048: the gate never depends on whether the number is registered.
update private.otp_limits set value = 300 where key = 'global_hour';
insert into fx values ('registered', tests.create_phone_user('+919000180001')::text);
select tests.create_published_provider((select value::uuid from fx where key = 'registered'), '+919000180001', 'Enumeration Listing');
select is(
  (public.otp_send_gate('+919000180001', timestamptz '2026-10-11 10:00+00'))::text,
  (public.otp_send_gate('+919000180002', timestamptz '2026-10-11 10:00+00'))::text,
  'registered and unregistered numbers get the identical gate answer');

-- Privacy of the log: no phone number, only a 32-byte keyed hash and an 8-char block.
select is(
  (select count(*)::int from private.otp_send_log where length(block) <> 8 or length(phone_hash) <> 32),
  0, 'the send log holds no phone number');

-- Callability.
select tests.authenticate_as_anon();
select throws_ok($$ select public.otp_send_gate('+919000180003') $$, '42501', null, 'anon cannot call the gate');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'registered'));
select throws_ok($$ select public.otp_send_gate('+919000180003') $$, '42501', null, 'authenticated users cannot call the gate');
reset role;

select * from finish();
rollback;
