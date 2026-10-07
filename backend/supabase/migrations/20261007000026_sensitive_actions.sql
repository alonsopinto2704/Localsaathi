-- 0026: phase 055, recent authentication for sensitive actions, enforced in the
-- database so a valid-but-old session cannot perform them.
--
-- Why a grant instead of a check inside each endpoint: two of the actions are
-- executed by services we do not control (GoTrue changes the phone number, the
-- delete-account Edge Function removes the user). A short-lived, single-use
-- grant issued only when the session's last factor proof is recent gives both
-- of them something to check, and the client cannot mint one.
--
-- Flow: the app calls request_sensitive_action(action). It succeeds only if the
-- token's `amr` claim shows a factor proof (SMS code / TOTP) within 5 minutes,
-- and records a grant for 10 minutes. The grant is consumed once:
--   phone_change   -> by the trigger below when GoTrue starts the change
--   delete_account -> by the Edge Function (service role) before deleting
-- After re-authenticating the app returns to the reviewed screen; nothing runs
-- automatically (the grant authorises, the user still confirms).

create table private.sensitive_grants (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (action in ('phone_change', 'delete_account', 'export_private_evidence')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);
create index sensitive_grants_lookup on private.sensitive_grants (user_id, action, created_at desc);
revoke all on private.sensitive_grants from public, anon, authenticated;

-- Seconds since the newest factor proof in the caller's token, or null if the
-- token shows none. Refreshing a session keeps the original amr timestamps, so
-- this measures when the user last proved control of a factor, not token age.
create function private.auth_age_seconds(p_now timestamptz default now())
returns int
language sql
stable
set search_path = ''
as $$
  select (extract(epoch from p_now) - max((e->>'timestamp')::numeric))::int
  from jsonb_array_elements(
         case when jsonb_typeof(auth.jwt() -> 'amr') = 'array' then auth.jwt() -> 'amr' else '[]'::jsonb end
       ) e
  where e->>'method' in ('otp', 'sms', 'totp', 'phone')
    and (e->>'timestamp') ~ '^[0-9]+(\.[0-9]+)?$';
$$;

create function public.request_sensitive_action(p_action text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_age int;
  v_expires timestamptz := now() + interval '10 minutes';
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in first';
  end if;
  if p_action is null or p_action not in ('phone_change', 'delete_account', 'export_private_evidence') then
    raise exception 'validation_failed: unknown sensitive action';
  end if;
  v_age := private.auth_age_seconds();
  if v_age is null or v_age > 300 or v_age < -60 then
    raise exception 'reauth_required: confirm with a new code before this action';
  end if;
  if (select count(*) from private.sensitive_grants
        where user_id = v_uid and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'rate_limited: too many confirmations, try again later';
  end if;
  -- One live grant per action: a newer request replaces the older one.
  update private.sensitive_grants set consumed_at = now()
    where user_id = v_uid and action = p_action and consumed_at is null;
  insert into private.sensitive_grants (user_id, action, expires_at) values (v_uid, p_action, v_expires);
  return jsonb_build_object('ok', true, 'action', p_action, 'expiresAt', v_expires);
end;
$$;

-- Atomically takes the newest unexpired, unconsumed grant. True if one existed.
create function private.consume_grant(p_user uuid, p_action text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id bigint;
begin
  select id into v_id from private.sensitive_grants
    where user_id = p_user and action = p_action and consumed_at is null and expires_at > now()
    order by created_at desc limit 1
    for update skip locked;
  if v_id is null then
    return false;
  end if;
  update private.sensitive_grants set consumed_at = now() where id = v_id;
  return true;
end;
$$;

-- Edge Functions (service role) consume a grant for the caller they verified.
create function public.consume_sensitive_grant(p_user_id uuid, p_action text)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select private.consume_grant(p_user_id, p_action);
$$;

-- GoTrue starts a phone change by writing auth.users.phone_change and
-- phone_change_sent_at. Refuse unless the user just re-authenticated. The
-- check is on every send, so a pending change cannot be re-sent from a stale
-- session either. Confirming the code (phone changes) needs no second grant:
-- possession of the new number is the proof.
create function private.guard_phone_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.phone_change, '') <> ''
     and new.phone_change_sent_at is distinct from old.phone_change_sent_at then
    if not private.consume_grant(new.id, 'phone_change') then
      raise exception 'reauth_required: confirm with a new code before changing your number';
    end if;
  end if;
  return new;
end;
$$;

create trigger auth_users_guard_phone_change
  before update of phone_change, phone_change_sent_at on auth.users
  for each row execute function private.guard_phone_change();

revoke execute on function public.request_sensitive_action(text), public.consume_sensitive_grant(uuid, text),
  private.consume_grant(uuid, text), private.auth_age_seconds(timestamptz) from public, anon, authenticated;
grant execute on function public.request_sensitive_action(text) to authenticated;
grant execute on function public.consume_sensitive_grant(uuid, text) to service_role;
