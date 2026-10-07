-- 0024: phases 042, 047, 048. OTP send gate ("pumping" protection), one
-- server-side definition of a supported mobile number, and my_account in the
-- documented E.164 form.
--
-- Where this runs: the Supabase Auth "Send SMS" hook (Edge Function
-- `send-sms-hook`) calls public.otp_send_gate() with the service role BEFORE it
-- asks the SMS provider to deliver anything. Auth calls the hook for every code
-- no matter which client or direct HTTP request asked for it, so this cannot be
-- bypassed by skipping the app. The gate never looks at profiles or accounts,
-- so its answer cannot reveal whether a number is registered.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- 042: the single server definition of a number we will send an SMS to.
-- Mirrors PhoneUtils (Dart): +91, ten digits, first digit 6-9. Fixture:
-- docs/contracts/fixtures/phone-cases.json (backend/test/phone-fixtures.test.mjs).
create function private.is_supported_mobile(p_e164 text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_e164 ~ '^\+91[6-9][0-9]{9}$', false);
$$;

-- ---------------------------------------------------------------------------
-- 047: limits are data, so an operator can tighten them during an attack
-- without a deploy. Defaults are deliberately conservative for a launch city.
create table private.otp_limits (
  key text primary key,
  value int not null check (value >= 0),
  note text not null
);
insert into private.otp_limits (key, value, note) values
  ('per_number_hour', 3, 'codes to one number per rolling hour'),
  ('per_number_day', 8, 'codes to one number per rolling 24 h'),
  ('per_block_hour', 30, 'codes to one 10,000-number block (first 8 characters of E.164) per hour: sequential-range pumping'),
  ('global_hour', 300, 'all codes per rolling hour; reaching it opens the circuit breaker'),
  ('global_day', 1500, 'all codes per rolling 24 h; reaching it opens the circuit breaker'),
  ('breaker_minutes', 60, 'how long the breaker stays open before sending resumes');

create table private.otp_settings (
  id boolean primary key default true check (id),
  -- Keyed hash so the send log never stores a phone number.
  pepper bytea not null default extensions.gen_random_bytes(32),
  breaker_open_until timestamptz,
  breaker_reason text
);
insert into private.otp_settings default values;

create table private.otp_send_log (
  id bigint generated always as identity primary key,
  phone_hash bytea not null,
  block text not null,
  sent_at timestamptz not null default now()
);
create index otp_send_log_hash_time on private.otp_send_log (phone_hash, sent_at desc);
create index otp_send_log_block_time on private.otp_send_log (block, sent_at desc);
create index otp_send_log_time on private.otp_send_log (sent_at desc);

-- Aggregate counters only: no number, no code, no message text.
create table private.otp_stats (
  day date not null,
  metric text not null,
  n int not null default 0,
  primary key (day, metric)
);

revoke all on private.otp_limits, private.otp_settings, private.otp_send_log, private.otp_stats
  from public, anon, authenticated;

create function private.otp_bump(p_metric text, p_now timestamptz)
returns void
language sql
set search_path = ''
as $$
  insert into private.otp_stats (day, metric, n) values ((p_now at time zone 'utc')::date, p_metric, 1)
  on conflict (day, metric) do update set n = private.otp_stats.n + 1;
$$;

create function private.otp_limit(p_key text)
returns int
language sql
stable
set search_path = ''
as $$
  select value from private.otp_limits where key = p_key;
$$;

-- The gate. `p_now` exists only so tests can move the clock.
create function public.otp_send_gate(p_phone text, p_now timestamptz default now())
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
  v_block := substr(v_phone, 1, 8);

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
    return jsonb_build_object('allowed', false, 'reason', 'service_paused',
      'retryAfterSeconds', private.otp_limit('breaker_minutes') * 60);
  end if;
  select count(*) into v_n from private.otp_send_log where sent_at > v_day;
  if v_n >= private.otp_limit('global_day') then
    update private.otp_settings
      set breaker_open_until = p_now + make_interval(mins => private.otp_limit('breaker_minutes')),
          breaker_reason = 'global_day';
    perform private.write_audit('otp_breaker_opened', 'otp', 'global', 'global_day limit reached');
    perform private.otp_bump('breaker_opened', p_now);
    return jsonb_build_object('allowed', false, 'reason', 'service_paused',
      'retryAfterSeconds', private.otp_limit('breaker_minutes') * 60);
  end if;

  insert into private.otp_send_log (phone_hash, block, sent_at) values (v_hash, v_block, p_now);
  perform private.otp_bump('allowed', p_now);
  return jsonb_build_object('allowed', true);
end;
$$;

-- The provider's answer, as a counter only (phase 046: aggregate failures
-- without storing message contents).
create function public.otp_record_delivery(p_outcome text, p_now timestamptz default now())
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_outcome not in ('delivered', 'rejected', 'timeout', 'duplicate') then
    raise exception 'validation_failed: unknown delivery outcome';
  end if;
  perform private.otp_bump('delivery_' || p_outcome, p_now);
end;
$$;

-- Operator control: close the breaker after the cause is understood.
create function public.otp_breaker_reset()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.otp_settings set breaker_open_until = null, breaker_reason = null;
  perform private.write_audit('otp_breaker_reset', 'otp', 'global');
end;
$$;

-- Retention: the log only needs the last 24 h of decisions. Schedule daily.
create function public.purge_otp_send_log(p_now timestamptz default now())
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n int;
begin
  delete from private.otp_send_log where sent_at < p_now - interval '48 hours';
  get diagnostics v_n = row_count;
  delete from private.otp_stats where day < (p_now at time zone 'utc')::date - 90;
  return v_n;
end;
$$;

revoke execute on function public.otp_send_gate(text, timestamptz), public.otp_record_delivery(text, timestamptz),
  public.otp_breaker_reset(), public.purge_otp_send_log(timestamptz) from public, anon, authenticated;
grant execute on function public.otp_send_gate(text, timestamptz), public.otp_record_delivery(text, timestamptz),
  public.otp_breaker_reset(), public.purge_otp_send_log(timestamptz) to service_role;
revoke execute on function private.otp_bump(text, timestamptz), private.otp_limit(text) from public;

-- ---------------------------------------------------------------------------
-- 048: my_account returned GoTrue's '+'-less phone although the contract says
-- E.164 with '+'. Same body otherwise.
create or replace function public.my_account()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', u.id,
    'phoneE164', coalesce(private.normalize_e164(u.phone), u.phone),
    'createdAt', u.created_at,
    'profileId', pp.id,
    'phoneVerifiedAt', u.phone_confirmed_at,
    'lastSignedInAt', u.last_sign_in_at,
    'isSuspended', coalesce(pp.moderation_status = 'suspended', false),
    'suspensionReason', pp.suspension_reason
  )
  from auth.users u
  left join public.provider_profiles pp on pp.user_id = u.id
  where u.id = auth.uid();
$$;
revoke execute on function public.my_account() from public, anon;
grant execute on function public.my_account() to authenticated;
