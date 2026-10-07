-- Consent, verification, credentials, reports, and the admin allowlist.
--
-- Mirrors lib/domain/models/moderation.dart. The two verification trails
-- (phone vs credentials) are modelled as one table with a `kind` column, on
-- purpose: it makes "OTP never writes a credentials row" a one-line check
-- instead of two tables that could drift apart.

create type public.consent_kind as enum (
  'display_phone_number', 'whatsapp_contact', 'public_profile', 'marketing_contact'
);
create type public.verification_kind as enum ('phone', 'credentials');
create type public.verification_status as enum ('not_started', 'pending', 'approved', 'rejected');
create type public.report_reason as enum (
  'wrong_phone_number', 'incorrect_details', 'no_longer_in_business', 'spam_or_misleading', 'other'
);
create type public.report_status as enum ('submitted', 'under_review', 'actioned', 'dismissed');

-- Who can moderate. Deliberately a tiny allowlist table rather than a role
-- claim baked into the JWT, so granting/revoking admin is a plain row
-- insert/delete an operator can do from the SQL editor -- no token refresh,
-- no redeploy.
create table public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  added_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.app_admins a where a.user_id = auth.uid());
$$;

-- Records, not booleans: "when did they agree, and to what wording" is what
-- matters if a Play Store policy question or a dispute ever comes up.
create table public.consent_records (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  kind public.consent_kind not null,
  granted boolean not null,
  recorded_at timestamptz not null default now(),
  wording_version text not null default 'consent-v1',
  phone_e164 text,
  withdrawn_at timestamptz
);

-- kind = 'phone' rows are written only by the trigger in 0007_auth_sync.sql,
-- on a confirmed OTP. kind = 'credentials' rows are written only by
-- record_credential_review() in 0008_functions.sql, which is admin-only. A
-- provider cannot reach either path directly -- see 0009_rls.sql.
create table public.verification_records (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  kind public.verification_kind not null,
  status public.verification_status not null,
  created_at timestamptz not null default now(),
  method text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  note text
);

-- Professional credentials as *claimed* by the provider (status defaults to
-- 'pending' and a provider-authored row can never set it to anything else --
-- enforced in 0009_rls.sql). `status` only moves to approved/rejected via
-- record_credential_review(), which only is_admin() can call.
create table public.credential_records (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  title text not null,
  status public.verification_status not null default 'pending',
  issuing_body text,
  registration_number text,
  valid_until date,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  -- Pointer into a private Storage bucket. Never a public URL.
  evidence_storage_path text
);

-- Customers report, never edit. Reporters are usually guests (the product
-- never requires customer sign-in), so there is no reporter identity to key
-- "already reported" off server-side -- see docs/backend-contract.md for how
-- that is handled on-device instead.
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  reason public.report_reason not null,
  status public.report_status not null default 'submitted',
  details text check (char_length(details) <= 1000),
  reporter_phone_e164 text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  resolution_note text
);

-- Defense in depth for "a provider cannot grant themselves a credentials
-- badge": even though 0009_rls.sql grants no UPDATE policy on this table to
-- `authenticated` (only record_credential_review(), a SECURITY DEFINER
-- function, can move status to approved/rejected), this trigger also forces
-- a non-admin's INSERT to 'pending' so a crafted payload can never slip a
-- different status in at creation time either.
create or replace function public.force_pending_credential_status()
returns trigger
language plpgsql
as $$
begin
  if not public.is_admin() then
    new.status := 'pending';
    new.reviewed_at := null;
    new.reviewed_by := null;
  end if;
  return new;
end;
$$;

create trigger trg_force_pending_credential
  before insert on public.credential_records
  for each row execute function public.force_pending_credential_status();
