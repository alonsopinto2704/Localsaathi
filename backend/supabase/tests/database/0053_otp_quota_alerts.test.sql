-- Audit follow-up (migration 0053): block size, refund of rejected sends,
-- breaker-open signal. Synthetic numbers +9190006xxxxx / +9190007xxxxx.
begin;
select plan(9);

-- 1. A block is +91 and six digits (10,000 numbers), as documented.
update private.otp_limits set value = 2 where key = 'per_block_hour';
select is((public.otp_send_gate('+919000600001', timestamptz '2026-11-01 10:00+00')->>'allowed')::boolean, true, 'first number in the block');
select is((public.otp_send_gate('+919000600002', timestamptz '2026-11-01 10:00+00')->>'allowed')::boolean, true, 'second number in the block');
select is((public.otp_send_gate('+919000600003', timestamptz '2026-11-01 10:00+00')->>'reason'), 'block_limit',
  'the third number in the same 10,000-number block is refused');
select is((public.otp_send_gate('+919000610001', timestamptz '2026-11-01 10:00+00')->>'allowed')::boolean, true,
  'a number 10,000 away is a different block (an 8-character block would have refused it)');
select is((select note ~ '10,000-number block \(first 9 characters' from private.otp_limits where key = 'per_block_hour'), true,
  'the limit note says what the code does');
update private.otp_limits set value = 30 where key = 'per_block_hour';

-- 2. A rejected send gives the quota back; a timeout (possibly delivered, billed) does not.
select public.otp_send_gate('+919000700001', timestamptz '2026-11-01 11:00+00' + (i || ' minutes')::interval) from generate_series(0, 2) i;
select public.otp_record_delivery('rejected', timestamptz '2026-11-01 11:03+00', '+919000700001');
select is((public.otp_send_gate('+919000700001', timestamptz '2026-11-01 11:04+00')->>'allowed')::boolean, true,
  'after a provider rejection the user is not locked out by it');
select public.otp_send_gate('+919000700002', timestamptz '2026-11-01 11:00+00' + (i || ' minutes')::interval) from generate_series(0, 2) i;
select public.otp_record_delivery('timeout', timestamptz '2026-11-01 11:03+00', '+919000700002');
select is((public.otp_send_gate('+919000700002', timestamptz '2026-11-01 11:04+00')->>'reason'), 'number_limit',
  'a timeout still counts against the quota');

-- 3. The call that opens the breaker says so, exactly once, and it is audited.
update private.otp_limits set value = 2 where key = 'global_hour';
select public.otp_send_gate('+919000710001', timestamptz '2026-11-02 10:00+00');
select public.otp_send_gate('+919000720001', timestamptz '2026-11-02 10:00+00');
select is((public.otp_send_gate('+919000730001', timestamptz '2026-11-02 10:00+00')->>'breakerOpened')::boolean, true,
  'the opening refusal carries breakerOpened');
select is((public.otp_send_gate('+919000740001', timestamptz '2026-11-02 10:01+00')->'breakerOpened') is null
          and (select count(*) = 1 from private.audit_events where action = 'otp_breaker_opened'), true,
  'later refusals do not, and one audit row exists');

select * from finish();
rollback;
