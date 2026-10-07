-- Phase 036: append-only audit trail for privileged decisions (moderation,
-- credential review, market activation, admin grants, account deletion).
--
-- Lives in `private` (not exposed by PostgREST, no API-role grants). The only
-- writer is private.write_audit(), a SECURITY DEFINER function no client can
-- execute -- it is called from inside other definer functions/triggers, in the
-- SAME transaction as the action, so if the audit insert fails the action is
-- rolled back too ("stop actions requiring audit if recording fails").
-- UPDATE/DELETE/TRUNCATE raise for everyone; only a superuser disabling the
-- triggers could rewrite history, which is outside the application's threat
-- model and visible in Postgres logs.
--
-- Operational logs (Edge Function/Postgres logs) are separate and short-lived;
-- this table is the application's record of who decided what, and why.

create table private.audit_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_id uuid,                 -- auth.uid() of the caller; null for system/SQL-editor actions
  actor_role text,               -- JWT role claim: authenticated / service_role / null
  action text not null check (action ~ '^[a-z_]+$'),
  target_type text not null,
  target_id text,
  reason text check (char_length(reason) <= 1000),
  correlation_id text not null,
  details jsonb not null default '{}'
);
create index audit_events_target on private.audit_events (target_type, target_id, occurred_at desc);
create index audit_events_time on private.audit_events (occurred_at desc);

revoke all on private.audit_events from public, anon, authenticated;

create function private.reject_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_events is append-only';
end;
$$;

create trigger audit_events_no_update_delete
  before update or delete on private.audit_events
  for each row execute function private.reject_audit_mutation();
create trigger audit_events_no_truncate
  before truncate on private.audit_events
  for each statement execute function private.reject_audit_mutation();

-- Redaction rule: details carry ids, enum values and counts, never contact
-- data. A phone-like digit run is refused rather than stored.
create function private.write_audit(
  p_action text, p_target_type text, p_target_id text,
  p_reason text default null, p_details jsonb default '{}'
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_headers jsonb := nullif(current_setting('request.headers', true), '')::jsonb;
  v_id bigint;
begin
  -- UUIDs (ids are expected in details) are removed before looking for a
  -- phone-like digit run; a 12-digit final UUID segment is not a phone.
  if regexp_replace(coalesce(p_details, '{}')::text || ' ' || coalesce(p_reason, ''),
                    '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '', 'g') ~ '\d{10,}' then
    raise exception 'audit_redaction: details or reason contain a phone-like number';
  end if;
  insert into private.audit_events (actor_id, actor_role, action, target_type, target_id, reason, correlation_id, details)
  values (
    auth.uid(), auth.role(), p_action, p_target_type, p_target_id, nullif(btrim(p_reason), ''),
    coalesce(v_headers->>'x-request-id', v_headers->>'x-correlation-id', gen_random_uuid()::text),
    coalesce(p_details, '{}')
  )
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function private.write_audit(text, text, text, text, jsonb) from public, anon, authenticated;

-- Admin grants/revocations are themselves privileged decisions.
create function private.audit_admin_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform private.write_audit('admin_granted', 'user', new.user_id::text);
  else
    perform private.write_audit('admin_revoked', 'user', old.user_id::text);
  end if;
  return null;
end;
$$;

create trigger app_admins_audit
  after insert or delete on public.app_admins
  for each row execute function private.audit_admin_change();

-- Admin read path (newest first, keyset-paginated, capped).
create function public.admin_audit_events(p_limit int default 100, p_before_id bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may read the audit trail';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(e) order by e.id desc)
    from (
      select * from private.audit_events
      where p_before_id is null or id < p_before_id
      order by id desc
      limit least(greatest(coalesce(p_limit, 100), 1), 500)
    ) e
  ), '[]'::jsonb);
end;
$$;
revoke execute on function public.admin_audit_events(int, bigint) from public, anon;
grant execute on function public.admin_audit_events(int, bigint) to authenticated;

-- Moderation and credential review now leave attributable evidence, and a
-- suspension must say why. Same signatures and return types as 0008.
create or replace function public.set_listing_moderation(
  p_provider_id uuid, p_status public.moderation_status, p_reason text default null
)
returns public.provider_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.provider_profiles;
  v_old public.moderation_status;
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may change moderation status';
  end if;
  if p_status = 'suspended' and coalesce(btrim(p_reason), '') = '' then
    raise exception 'validation_failed: a suspension needs a reason';
  end if;
  select moderation_status into v_old from public.provider_profiles where id = p_provider_id for update;
  if not found then
    raise exception 'not_found: profile not found';
  end if;
  update public.provider_profiles
    set moderation_status = p_status, suspension_reason = case when p_status = 'suspended' then p_reason end
    where id = p_provider_id
    returning * into v_row;
  perform private.write_audit('listing_moderation_set', 'provider_profile', p_provider_id::text, p_reason,
    jsonb_build_object('from', v_old, 'to', p_status));
  return v_row;
end;
$$;

create or replace function public.record_credential_review(
  p_provider_id uuid, p_credential_id uuid, p_status public.verification_status, p_note text default null
)
returns public.credential_records
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.credential_records;
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may review credentials';
  end if;
  if p_status not in ('approved', 'rejected') then
    raise exception 'validation_failed: a review decides approved or rejected';
  end if;
  update public.credential_records
    set status = p_status, reviewed_at = now(), reviewed_by = auth.uid()
    where id = p_credential_id and provider_id = p_provider_id
    returning * into v_row;
  if v_row.id is null then
    raise exception 'not_found: credential record not found';
  end if;
  insert into public.verification_records (provider_id, kind, status, method, reviewed_by, reviewed_at, note)
  values (p_provider_id, 'credentials', p_status, 'document_review', auth.uid(), now(), p_note);
  perform private.write_audit('credential_reviewed', 'credential_record', p_credential_id::text, p_note,
    jsonb_build_object('provider_id', p_provider_id, 'status', p_status));
  return v_row;
end;
$$;
