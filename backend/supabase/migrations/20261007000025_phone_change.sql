-- 0025: phase 052, verified phone change.
--
-- GoTrue performs the change itself: updateUser(phone) sends a code to the NEW
-- number and the old number stays on auth.users until that code is verified;
-- auth.users.phone is UNIQUE, so a number that belongs to another account is
-- refused by Auth and never reaches this trigger. This migration decides what
-- the database does when the change commits.
--
-- Rules:
--  * the provider profile keeps its owner; only phone_e164 follows the verified
--    number (no profile ever moves between accounts through this path);
--  * consent to show a phone number was given for the OLD number. The new one
--    starts without display or WhatsApp consent, which also pauses a published
--    listing (never silently re-listed); the owner consents again to publish.
--    ASSUMPTION recorded in tasks/evidence/phase-052.md: safest default, no
--    number is exposed that the owner has not approved;
--  * the change is one atomic statement: if any step fails (for example the new
--    number is already the phone_e164 of another profile) the whole change
--    rolls back and the original verified number stays in force;
--  * an audit event records that a change happened, never either number.

create or replace function public.handle_auth_phone_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := private.normalize_e164(new.phone);
  v_changed boolean;
  v_profile uuid;
begin
  if new.phone_confirmed_at is null or v_phone is null then
    return new;
  end if;

  if new.phone is distinct from old.phone or new.phone_confirmed_at is distinct from old.phone_confirmed_at then
    -- A real change of number (not first confirmation).
    v_changed := old.phone is not null
      and private.normalize_e164(old.phone) is distinct from v_phone;

    select pp.id into v_profile from public.provider_profiles pp where pp.user_id = new.id;

    if v_changed and v_profile is not null then
      update public.provider_profiles
        set phone_e164 = v_phone,
            phone_display_consented = false,
            whatsapp_enabled = false
        where id = v_profile and phone_e164 is distinct from v_phone;

      insert into public.consent_records (provider_id, kind, granted, phone_e164, withdrawn_at, wording_version)
      values
        (v_profile, 'display_phone_number', false, v_phone, now(), 'consent-v1'),
        (v_profile, 'whatsapp_contact', false, v_phone, now(), 'consent-v1');
    elsif v_profile is not null then
      update public.provider_profiles
        set phone_e164 = v_phone
        where id = v_profile and phone_e164 is distinct from v_phone;
    end if;

    if v_changed then
      perform private.write_audit('phone_changed', 'user', new.id::text, 'verified phone change');
    end if;

    insert into public.verification_records (provider_id, kind, status, method, note)
    select pp.id, 'phone', 'approved', 'otp_sms',
           'Phone control confirmed by one-time code. This says nothing about professional qualifications.'
    from public.provider_profiles pp
    where pp.user_id = new.id and pp.phone_e164 = v_phone;
  end if;

  return new;
end;
$$;

-- Deferred from the 2026-10-07 audit: E.164 on the remaining phone columns.
-- NOT VALID so an upgrade never fails on legacy rows; every new write is held
-- to the format. Validate after reviewing `select ... where not (...)`.
alter table public.consent_records
  add constraint consent_phone_is_e164 check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$') not valid;
alter table public.reports
  add constraint report_phone_is_e164 check (reporter_phone_e164 is null or reporter_phone_e164 ~ '^\+[1-9][0-9]{7,14}$') not valid;
