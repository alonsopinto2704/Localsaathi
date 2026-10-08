-- 0053: audit follow-ups (phase 047).
--  1. per_block_hour: substr(phone, 1, 8) of '+91XXXXXXXXXX' is '+91' plus FIVE
--     digits = a 100,000-number block, while docs and the limit note promised
--     10,000. Code now takes 9 characters (+91 and six digits); comment, note
--     and docs agree. Log rows written before this migration carry 8-character
--     blocks and simply stop matching (they age out within 48 h).
--  2. A provider-rejected send does not consume the user's quota: the hook
--     reports the outcome WITH the number and the most recent gate row for that
--     number is removed. Timeouts are NOT refunded: the SMS may have been
--     delivered and billed, so they keep counting (spend control wins).
--  3. The call that opens the global breaker says so ('breakerOpened'), so the
--     hook can emit an alertable log line in addition to the audit row
--     'otp_breaker_opened' that the gate already writes.

update private.otp_limits
  set note = 'codes to one 10,000-number block (first 9 characters of E.164: +91 and six digits) per hour: sequential-range pumping'
  where key = 'per_block_hour';

-- The gate. `p_now` exists only so tests can move the clock.
create or replace function public.otp_send_gate(p_phone text, p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := private.normalize_e164(p_phone);
  v_pepper bytea;
  v_hash bytea;
  v_block text;
  v_open timestamptz;
  v_hour timestamptz := p_now - interval '1 hour';
  v_day timestamptz := p_now - interval '24 hours';
  v_n int;
  v_oldest timestamptz;
begin
  if v_phone is null or not private.is_supported_mobile(v_phone) then
    perform private.otp_bump('denied_unsupported_number', p_now);
    return jsonb_build_object('allowed', false, 'reason', 'unsupported_number');
  end if;

  -- One gate decision at a time: counts and the breaker must be consistent.
  perform pg_advisory_xact_lock(hashtext('otp_send_gate'));

  select pepper, breaker_open_until into v_pepper, v_open from private.otp_settings;
  if v_open is not null and v_open > p_now then
    perform private.otp_bump('denied_service_paused', p_now);
    return jsonb_build_object(
      'allowed', false, 'reason', 'service_paused',
      'retryAfterSeconds', ceil(extract(epoch from (v_open - p_now)))::int);
  end if;

  v_hash := extensions.digest(v_pepper || convert_to(v_phone, 'utf8'), 'sha256');
  v_block := substr(v_phone, 1, 9); -- +91 and six digits: a 10,000-number block

  select count(*), min(sent_at) into v_n, v_oldest
    from private.otp_send_log where phone_hash = v_hash and sent_at > v_hour;
  if v_n >= private.otp_limit('per_number_hour') then
    perform private.otp_bump('denied_number_limit', p_now);
    return jsonb_build_object(
      'allowed', false, 'reason', 'number_limit',
      'retryAfterSeconds', greatest(1, ceil(extract(epoch from (v_oldest + interval '1 hour' - p_now)))::int));
  end if;

  select count(*), min(sent_at) into v_n, v_oldest
    from private.otp_send_log where phone_hash = v_hash and sent_at > v_day;
  if v_n >= private.otp_limit('per_number_day') then
    perform private.otp_bump('denied_number_limit', p_now);
    return jsonb_build_object(
      'allowed', false, 'reason', 'number_limit',
      'retryAfterSeconds', greatest(1, ceil(extract(epoch from (v_oldest + interval '24 hours' - p_now)))::int));
  end if;

  select count(*) into v_n from private.otp_send_log where block = v_block and sent_at > v_hour;
  if v_n >= private.otp_limit('per_block_hour') then
    perform private.otp_bump('denied_block_limit', p_now);
    return jsonb_build_object('allowed', false, 'reason', 'block_limit', 'retryAfterSeconds', 600);
  end if;

  -- Global spend. Reaching either ceiling opens the breaker for everyone,
  -- records one audit event and stays open until it expires or an operator
  -- clears it (public.otp_breaker_reset).
  select count(*) into v_n from private.otp_send_log where sent_at > v_hour;
  if v_n >= private.otp_limit('global_hour') then
    update private.otp_settings
      set breaker_open_until = p_now + make_interval(mins => private.otp_limit('breaker_minutes')),
          breaker_reason = 'global_hour';
    perform private.write_audit('otp_breaker_opened', 'otp', 'global', 'global_hour limit reached');
    perform private.otp_bump('breaker_opened', p_now);
    return jsonb_build_object('allowed', false, 'reason', 'service_paused', 'breakerOpened', true,
      'retryAfterSeconds', private.otp_limit('breaker_minutes') * 60);
  end if;
  select count(*) into v_n from private.otp_send_log where sent_at > v_day;
  if v_n >= private.otp_limit('global_day') then
    update private.otp_settings
      set breaker_open_until = p_now + make_interval(mins => private.otp_limit('breaker_minutes')),
          breaker_reason = 'global_day';
    perform private.write_audit('otp_breaker_opened', 'otp', 'global', 'global_day limit reached');
    perform private.otp_bump('breaker_opened', p_now);
    return jsonb_build_object('allowed', false, 'reason', 'service_paused', 'breakerOpened', true,
      'retryAfterSeconds', private.otp_limit('breaker_minutes') * 60);
  end if;

  insert into private.otp_send_log (phone_hash, block, sent_at) values (v_hash, v_block, p_now);
  perform private.otp_bump('allowed', p_now);
  return jsonb_build_object('allowed', true);
end;
$$;


drop function public.otp_record_delivery(text, timestamptz);
create function public.otp_record_delivery(p_outcome text, p_now timestamptz default now(), p_phone text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := private.normalize_e164(p_phone);
  v_hash bytea;
begin
  if p_outcome not in ('delivered', 'rejected', 'timeout', 'duplicate') then
    raise exception 'validation_failed: unknown delivery outcome';
  end if;
  perform private.otp_bump('delivery_' || p_outcome, p_now);
  -- ponytail: a rejected send is refunded without a cap; GoTrue's own 60 s
  -- per-number spacing and sms_sent=60/h still bound how fast an attacker can
  -- loop rejected sends. Add a refund counter if provider rejections become a vector.
  if p_outcome = 'rejected' and v_phone is not null then
    v_hash := extensions.digest((select pepper from private.otp_settings) || convert_to(v_phone, 'utf8'), 'sha256');
    delete from private.otp_send_log
      where id = (select id from private.otp_send_log where phone_hash = v_hash order by sent_at desc, id desc limit 1);
  end if;
end;
$$;
revoke execute on function public.otp_record_delivery(text, timestamptz, text) from public, anon, authenticated;
grant execute on function public.otp_record_delivery(text, timestamptz, text) to service_role;
