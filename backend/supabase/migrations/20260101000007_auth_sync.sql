-- Syncs Supabase Auth's phone identity onto provider_profiles.
--
-- This is the one trigger that makes "follow the backend's native auth flow
-- rather than building a custom OTP system" actually true end to end:
--
--   1. The client calls supabase.auth.signInWithOtp({phone}) and
--      verifyOtp(...). Supabase Auth owns the code, its delivery, its
--      expiry and its attempt limit -- none of that is reimplemented here.
--   2. The *only* thing this schema trusts is auth.users.phone_confirmed_at.
--      A client-submitted "phone verified" flag is never read by anything
--      in this schema; there is nowhere for one to even be sent.
--   3. The moment phone_confirmed_at is set (first verification) or phone
--      changes while already confirmed (phone-number-change flow), this
--      trigger (a) mirrors the new number onto provider_profiles.phone_e164
--      so the rest of the schema never has to look into auth.* under RLS,
--      and (b) appends a verification_records row with kind = 'phone',
--      status = 'approved'. No code outside this trigger can create a
--      kind = 'phone' / status = 'approved' row -- see 0009_rls.sql.
--
-- Why the sync can't violate provider_profiles.phone_e164's UNIQUE
-- constraint in practice: by the time this trigger runs, Supabase Auth has
-- already enforced that no other *confirmed* auth.users row has this phone
-- (verifyOtp would have failed first). The only way a stale provider_profiles
-- row could still hold this number is if its owning auth.users row was
-- deleted without cascading -- which `on delete cascade` on
-- provider_profiles.user_id rules out.
create or replace function public.handle_auth_phone_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.phone_confirmed_at is null then
    return new;
  end if;

  if new.phone is distinct from old.phone or new.phone_confirmed_at is distinct from old.phone_confirmed_at then
    update public.provider_profiles
      set phone_e164 = new.phone
      where user_id = new.id
        and phone_e164 is distinct from new.phone;

    if exists (select 1 from public.provider_profiles where user_id = new.id and phone_e164 = new.phone) then
      insert into public.verification_records (provider_id, kind, status, method, note)
      select pp.id, 'phone', 'approved', 'otp_sms',
             'Phone control confirmed by one-time code. This says nothing about professional qualifications.'
      from public.provider_profiles pp
      where pp.user_id = new.id;
    end if;
  end if;

  return new;
end;
$$;

create trigger on_auth_user_phone_verified
  after update on auth.users
  for each row execute function public.handle_auth_phone_change();
