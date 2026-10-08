-- 0051: audit follow-ups (phase 053).
--  1. Two-person rule: the administrator who approved a recovery case cannot
--     also carry it out. One rogue or compromised support account can no longer
--     approve, wait seven days and reassign an owner's login number alone.
--  2. The per-listing cap on cases let two throwaway accounts exhaust it for a
--     victim's (public) listing id and lock the real owner out of recovery.
--     The cap is now per claimant (and per claimant per listing). A flood on a
--     listing no longer blocks anyone; it writes a single audit alert instead.

create or replace function public.open_recovery_case(p_provider_id uuid, p_statement text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_case uuid;
  v_recent int;
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
        where claimant_user_id = v_uid and provider_id = p_provider_id
          and opened_at > now() - interval '30 days') >= 2 then
    raise exception 'rate_limited: you already asked about this listing; support will review it';
  end if;
  insert into private.recovery_cases (provider_id, claimant_user_id, statement)
  values (p_provider_id, v_uid, btrim(p_statement))
  returning id into v_case;
  perform private.write_audit('recovery_case_opened', 'provider_profile', p_provider_id::text, null,
    jsonb_build_object('case_id', v_case));
  -- Alert, never a block: the sixth case in 30 days (any claimants) is the
  -- signal that someone is probing this listing. Exactly one alert row.
  select count(*) into v_recent from private.recovery_cases
    where provider_id = p_provider_id and opened_at > now() - interval '30 days';
  if v_recent = 5 then
    perform private.write_audit('recovery_listing_flood', 'provider_profile', p_provider_id::text, null,
      jsonb_build_object('cases_30d', v_recent));
  end if;
  -- Deliberately says nothing about the listing.
  return jsonb_build_object('caseId', v_case, 'status', 'opened');
end;
$$;

create or replace function public.admin_execute_recovery(p_case_id uuid)
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
  if v_case.reviewed_by is not distinct from auth.uid() then
    raise exception 'not_owner: a different administrator than the approving reviewer must carry this out';
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
    jsonb_build_object('case_id', p_case_id, 'reviewed_by', v_case.reviewed_by));
  return jsonb_build_object('ok', true, 'caseId', p_case_id);
end;
$$;
