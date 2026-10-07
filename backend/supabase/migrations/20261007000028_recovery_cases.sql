-- 0028: phase 053, SIM-loss recovery.
--
-- Threat: an impersonator who knows a listing's public facts (name, area, even
-- its number) asks to take it over. Public knowledge is therefore worth
-- nothing in this flow. A transfer needs ALL of:
--   1. the claimant proves control of a NEW number (an ordinary verified
--      sign-in) and files a case with a short statement (no documents, no
--      numbers: minimal evidence);
--   2. a support administrator (own account, MFA, recent TOTP proof) records a
--      decision with a written rationale;
--   3. a 7-day waiting period during which the existing owner, if they can
--      still sign in, sees the case and can dispute it, which freezes it;
--   4. a second, separate execution step by a support administrator.
-- Preparing a recovery (1-2) and transferring (4) are different functions with
-- different checks. Nothing here ever lets a case decide itself.
--
-- What "transfer" means: the listing is never re-pointed at another account.
-- The ORIGINAL account (and its profile row) keeps existing; its login number
-- becomes the claimant's verified number, its sessions are revoked, and the
-- phone-change trigger (0025) pauses the listing and resets phone consent for
-- the new number. The claimant's temporary empty account is deleted.

create table private.recovery_cases (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  claimant_user_id uuid references auth.users(id) on delete set null,
  status text not null default 'opened'
    check (status in ('opened', 'approved', 'rejected', 'frozen', 'executed')),
  statement text not null check (char_length(statement) between 20 and 1000),
  opened_at timestamptz not null default now(),
  reviewed_by uuid,
  reviewed_at timestamptz,
  rationale text check (char_length(rationale) <= 1000),
  eligible_at timestamptz,
  disputed_at timestamptz,
  executed_at timestamptz
);
create index recovery_cases_provider on private.recovery_cases (provider_id, opened_at desc);
create index recovery_cases_claimant on private.recovery_cases (claimant_user_id, opened_at desc);
revoke all on private.recovery_cases from public, anon, authenticated;

-- Statement/rationale text must not carry phone numbers (they end up in audit
-- trails and support tooling).
create function private.assert_no_phone_digits(p_text text, p_what text)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if regexp_replace(coalesce(p_text, ''), '[\s().-]', '', 'g') ~ '\d{8,}' then
    raise exception 'validation_failed: % must not contain phone numbers', p_what;
  end if;
end;
$$;

create function public.open_recovery_case(p_provider_id uuid, p_statement text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_case uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated: sign in with your new number first';
  end if;
  if not exists (select 1 from auth.users u where u.id = v_uid and u.phone_confirmed_at is not null) then
    raise exception 'not_authenticated: a verified phone number is required';
  end if;
  if char_length(btrim(coalesce(p_statement, ''))) < 20 then
    raise exception 'validation_failed: describe in at least 20 characters how you operate this listing';
  end if;
  perform private.assert_no_phone_digits(p_statement, 'the statement');
  if exists (select 1 from public.provider_profiles where user_id = v_uid) then
    raise exception 'conflict: this account already has a listing';
  end if;
  select user_id into v_owner from public.provider_profiles where id = p_provider_id;
  if v_owner is null then
    raise exception 'not_found: listing not found';
  end if;
  if (select count(*) from private.recovery_cases
        where claimant_user_id = v_uid and opened_at > now() - interval '24 hours') >= 3 then
    raise exception 'rate_limited: too many recovery requests today';
  end if;
  if (select count(*) from private.recovery_cases
        where provider_id = p_provider_id and opened_at > now() - interval '30 days') >= 5 then
    raise exception 'rate_limited: this listing already has several recovery requests; contact support';
  end if;
  insert into private.recovery_cases (provider_id, claimant_user_id, statement)
  values (p_provider_id, v_uid, btrim(p_statement))
  returning id into v_case;
  perform private.write_audit('recovery_case_opened', 'provider_profile', p_provider_id::text, null,
    jsonb_build_object('case_id', v_case));
  -- Deliberately says nothing about the listing.
  return jsonb_build_object('caseId', v_case, 'status', 'opened');
end;
$$;

-- What the current owner sees: that someone asked, when, and the state. Never
-- who or why.
create function public.my_recovery_notices()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'caseId', c.id, 'status', c.status, 'openedAt', c.opened_at, 'eligibleAt', c.eligible_at)
         order by c.opened_at desc), '[]'::jsonb)
  from private.recovery_cases c
  join public.provider_profiles pp on pp.id = c.provider_id
  where pp.user_id = auth.uid() and c.status in ('opened', 'approved', 'frozen');
$$;

create function public.dispute_recovery_case(p_case_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case private.recovery_cases;
begin
  select c.* into v_case
    from private.recovery_cases c join public.provider_profiles pp on pp.id = c.provider_id
    where c.id = p_case_id and pp.user_id = auth.uid() and c.status in ('opened', 'approved')
    for update of c;
  if v_case.id is null then
    raise exception 'not_found: no open recovery request on your listing';
  end if;
  update private.recovery_cases set status = 'frozen', disputed_at = now() where id = v_case.id;
  perform private.write_audit('recovery_case_disputed', 'provider_profile', v_case.provider_id::text, null,
    jsonb_build_object('case_id', v_case.id));
  return jsonb_build_object('caseId', v_case.id, 'status', 'frozen');
end;
$$;

-- Support's queue: no documents, claimant number masked.
create function public.admin_recovery_queue()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin_role('support', false);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'caseId', c.id, 'status', c.status, 'openedAt', c.opened_at, 'eligibleAt', c.eligible_at,
      'disputedAt', c.disputed_at, 'statement', c.statement,
      'listing', pp.display_name,
      'claimantPhoneEnding', right(coalesce(u.phone, ''), 2)) order by c.opened_at)
    from private.recovery_cases c
    join public.provider_profiles pp on pp.id = c.provider_id
    left join auth.users u on u.id = c.claimant_user_id
    where c.status in ('opened', 'approved', 'frozen')), '[]'::jsonb);
end;
$$;

create function public.admin_review_recovery_case(p_case_id uuid, p_decision text, p_rationale text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case private.recovery_cases;
  v_eligible timestamptz;
begin
  perform private.require_admin_role('support');
  if p_decision not in ('approve', 'reject') then
    raise exception 'validation_failed: decision must be approve or reject';
  end if;
  if char_length(btrim(coalesce(p_rationale, ''))) < 20 then
    raise exception 'validation_failed: a written rationale of at least 20 characters is required';
  end if;
  perform private.assert_no_phone_digits(p_rationale, 'the rationale');
  select * into v_case from private.recovery_cases where id = p_case_id for update;
  if v_case.id is null then
    raise exception 'not_found: recovery case not found';
  end if;
  if p_decision = 'approve' and v_case.status <> 'opened' then
    raise exception 'conflict: only an open, undisputed case can be approved';
  end if;
  if p_decision = 'reject' and v_case.status not in ('opened', 'approved', 'frozen') then
    raise exception 'conflict: this case is already closed';
  end if;
  v_eligible := case when p_decision = 'approve' then now() + interval '7 days' end;
  update private.recovery_cases
    set status = case p_decision when 'approve' then 'approved' else 'rejected' end,
        reviewed_by = auth.uid(), reviewed_at = now(), rationale = btrim(p_rationale), eligible_at = v_eligible
    where id = p_case_id;
  perform private.write_audit('recovery_case_' || p_decision, 'provider_profile', v_case.provider_id::text, btrim(p_rationale),
    jsonb_build_object('case_id', p_case_id));
  return jsonb_build_object('caseId', p_case_id, 'eligibleAt', v_eligible);
end;
$$;

create function public.admin_execute_recovery(p_case_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case private.recovery_cases;
  v_owner uuid;
  v_phone text;
begin
  perform private.require_admin_role('support');
  select * into v_case from private.recovery_cases where id = p_case_id for update;
  if v_case.id is null then
    raise exception 'not_found: recovery case not found';
  end if;
  if v_case.status = 'executed' then
    raise exception 'conflict: this recovery was already carried out';
  end if;
  if v_case.status <> 'approved' or v_case.disputed_at is not null then
    raise exception 'conflict: only an approved, undisputed case can be carried out';
  end if;
  if v_case.eligible_at is null or v_case.eligible_at > now() then
    raise exception 'conflict: the waiting period has not ended';
  end if;
  select user_id into v_owner from public.provider_profiles where id = v_case.provider_id;
  select u.phone into v_phone from auth.users u
    where u.id = v_case.claimant_user_id and u.phone_confirmed_at is not null;
  if v_owner is null or v_phone is null then
    raise exception 'conflict: the listing or the claimant no longer exists';
  end if;
  if exists (select 1 from public.provider_profiles where user_id = v_case.claimant_user_id) then
    raise exception 'conflict: the claimant account has since created its own listing';
  end if;

  update private.recovery_cases set status = 'executed', executed_at = now() where id = p_case_id;
  -- Free the number, then move the ORIGINAL account onto it.
  delete from auth.users where id = v_case.claimant_user_id;
  if to_regclass('auth.sessions') is not null then
    execute 'delete from auth.sessions where user_id = $1' using v_owner;
  end if;
  update auth.users set phone = v_phone, phone_confirmed_at = now() where id = v_owner;
  perform private.write_audit('recovery_executed', 'provider_profile', v_case.provider_id::text, null,
    jsonb_build_object('case_id', p_case_id));
  return jsonb_build_object('ok', true, 'caseId', p_case_id);
end;
$$;

revoke execute on function public.open_recovery_case(uuid, text), public.my_recovery_notices(),
  public.dispute_recovery_case(uuid), public.admin_recovery_queue(),
  public.admin_review_recovery_case(uuid, text, text), public.admin_execute_recovery(uuid),
  private.assert_no_phone_digits(text, text) from public, anon, authenticated;
grant execute on function public.open_recovery_case(uuid, text), public.my_recovery_notices(),
  public.dispute_recovery_case(uuid), public.admin_recovery_queue(),
  public.admin_review_recovery_case(uuid, text, text), public.admin_execute_recovery(uuid) to authenticated;
