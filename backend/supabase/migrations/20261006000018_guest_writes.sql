-- Phase 033: guest submissions (reports, engagement taps, city requests)
-- through bounded, rate-limited RPCs instead of `insert ... with check (true)`.
--
-- 0013 already revoked the direct INSERT grants. There is no trustworthy
-- guest identity: the "source" below is a pseudonymous, daily-rotating hash of
-- the edge-provided client IP (or the signed-in user id). It is a throttling
-- signal, not proof of who someone is -- shared IPs (mobile carrier NAT) share
-- a budget, which is why limits are generous and per-target caps exist too.

create table private.rate_limits (
  bucket text not null,
  subject text not null,
  window_start timestamptz not null,
  hits int not null default 0,
  primary key (bucket, subject, window_start)
);
revoke all on private.rate_limits from public, anon, authenticated;

-- Null when no trustworthy client signal exists: callers then skip per-source
-- dedupe/limits (keeping per-target caps) instead of lumping every guest into
-- one shared bucket. Prefers cf-connecting-ip (set by the edge, not the
-- client); otherwise the RIGHTMOST x-forwarded-for hop, which the nearest
-- proxy appended -- the leftmost entries are whatever the client sent.
create function private.request_source()
returns text
language sql
stable
set search_path = ''
as $$
  with h as (select nullif(current_setting('request.headers', true), '')::jsonb as j),
  ip as (
    select btrim(coalesce(
      nullif(btrim(h.j->>'cf-connecting-ip'), ''),
      nullif(btrim((regexp_split_to_array(coalesce(h.j->>'x-forwarded-for', ''), ','))[
        array_length(regexp_split_to_array(coalesce(h.j->>'x-forwarded-for', ''), ','), 1)]), ''))) as v
    from h
  )
  select case
    when auth.uid() is not null then 'u:' || auth.uid()::text
    when (select v from ip) is not null then 'ip:' || md5((select v from ip) || current_date::text)
  end;
$$;

-- True if the caller still has budget in this window (and consumes one hit).
create function private.take_rate_token(p_bucket text, p_subject text, p_window interval, p_max int)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := to_timestamp(floor(extract(epoch from now()) / extract(epoch from p_window)) * extract(epoch from p_window));
  v_hits int;
begin
  insert into private.rate_limits (bucket, subject, window_start, hits)
  values (p_bucket, p_subject, v_start, 1)
  on conflict (bucket, subject, window_start) do update set hits = private.rate_limits.hits + 1
  returning hits into v_hits;
  return v_hits <= p_max;
end;
$$;

-- ---------------------------------------------------------------------------
alter table public.reports add column reporter_source text;

create function public.submit_report(
  p_provider_id uuid, p_reason public.report_reason, p_details text default null, p_reporter_phone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source text := private.request_source();
  v_phone text;
  v_existing uuid;
  v_id uuid;
begin
  if not public.is_publicly_listed(p_provider_id) then
    raise exception 'not_found: listing not found';
  end if;
  if char_length(coalesce(p_details, '')) > 1000 then
    raise exception 'validation_failed: details are limited to 1000 characters';
  end if;
  if nullif(btrim(p_reporter_phone), '') is not null then
    v_phone := private.normalize_e164(p_reporter_phone);
    if v_phone is null then
      raise exception 'validation_failed: reporter phone must be a valid number';
    end if;
  end if;

  -- Same reporter, same listing, within a day: one report, same receipt.
  select id into v_existing from public.reports
  where v_source is not null
    and provider_id = p_provider_id and reporter_source = v_source and created_at > now() - interval '24 hours'
  limit 1;
  if v_existing is not null then
    return jsonb_build_object('receiptId', v_existing, 'status', 'submitted');
  end if;

  if v_source is not null and (
       not private.take_rate_token('report:source:h', v_source, interval '1 hour', 5)
       or not private.take_rate_token('report:source:d', v_source, interval '1 day', 20)) then
    raise exception 'rate_limited: too many reports, try again later';
  end if;
  if not private.take_rate_token('report:provider:d', p_provider_id::text, interval '1 day', 50) then
    raise exception 'rate_limited: this listing has many open reports already';
  end if;

  insert into public.reports (provider_id, reason, details, reporter_phone_e164, reporter_source)
  values (p_provider_id, p_reason, nullif(btrim(p_details), ''), v_phone, v_source)
  returning id into v_id;
  return jsonb_build_object('receiptId', v_id, 'status', 'submitted');
end;
$$;

-- Taps and views feed provider statistics only. Over-budget events are
-- dropped silently: a guest's tap must never fail because of metrics.
create function public.record_engagement(
  p_provider_id uuid, p_type public.engagement_event_type,
  p_city_id text default null, p_locality_id text default null, p_category_id text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source text := private.request_source();
begin
  if not public.is_publicly_listed(p_provider_id) then
    return;
  end if;
  if v_source is not null and (
       not private.take_rate_token('engagement:' || p_type || ':' || p_provider_id, v_source, interval '1 hour', 10)
       or not private.take_rate_token('engagement:source:h', v_source, interval '1 hour', 300)) then
    return;
  end if;
  -- Without a source signal, a per-listing hourly cap still bounds the volume.
  if v_source is null and not private.take_rate_token('engagement:' || p_type || ':' || p_provider_id, 'no-source', interval '1 hour', 600) then
    return;
  end if;
  insert into public.engagement_events (provider_id, type, city_id, locality_id, category_id)
  values (
    p_provider_id, p_type,
    (select id from public.cities where id = p_city_id),
    (select id from public.localities where id = p_locality_id),
    (select id from public.service_categories where id = p_category_id)
  );
end;
$$;

create function public.request_city(p_city_name text, p_state_name text default null, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source text := private.request_source();
  v_id uuid;
begin
  if char_length(btrim(coalesce(p_city_name, ''))) not between 2 and 80
     or char_length(coalesce(p_state_name, '')) > 80
     or char_length(coalesce(p_note, '')) > 500 then
    raise exception 'validation_failed: city 2-80 characters, state up to 80, note up to 500';
  end if;
  if not private.take_rate_token('city_request:source:d', coalesce(v_source, 'no-source'), interval '1 day',
                                  case when v_source is null then 200 else 5 end) then
    raise exception 'rate_limited: too many requests today';
  end if;
  insert into public.city_requests (city_name, state_name, note, submitted_by_phone)
  values (btrim(p_city_name), nullif(btrim(p_state_name), ''), nullif(btrim(p_note), ''),
          -- Only ever the signed-in provider's own verified number, never client input.
          (select phone_e164 from public.provider_profiles where user_id = auth.uid()))
  returning id into v_id;
  return jsonb_build_object('receiptId', v_id, 'status', 'received');
end;
$$;

revoke execute on function
  public.submit_report(uuid, public.report_reason, text, text),
  public.record_engagement(uuid, public.engagement_event_type, text, text, text),
  public.request_city(text, text, text),
  private.request_source(), private.take_rate_token(text, text, interval, int)
from public;
grant execute on function
  public.submit_report(uuid, public.report_reason, text, text),
  public.record_engagement(uuid, public.engagement_event_type, text, text, text),
  public.request_city(text, text, text)
to anon, authenticated;

-- The old "anyone may insert" policies are now unreachable (no grant); drop
-- them so a future grant cannot silently revive unbounded writes.
drop policy "anyone may file a report" on public.reports;
drop policy "anyone may record an engagement event" on public.engagement_events;
drop policy "anyone may request a city" on public.city_requests;
