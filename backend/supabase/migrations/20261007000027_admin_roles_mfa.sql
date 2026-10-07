-- 0027: phase 054, administrator MFA and separate roles (also the privileged
-- half of phase 055: sensitive admin actions need a recent factor proof).
--
-- Before: public.is_admin() meant "has a row in app_admins", for every action
-- and any session strength. After:
--   * an administrator needs a row in app_admins AND at least one role in
--     private.admin_roles (support, moderation, credential_review,
--     infrastructure) AND an MFA session (JWT aal = 'aal2');
--   * roles live only in a private table changed from the SQL editor / service
--     role. No client-writable metadata (raw_user_meta_data, app_metadata
--     claims, a profile column) is ever consulted, so editing your own profile
--     or user metadata cannot confer privilege;
--   * the most sensitive actions additionally require that the TOTP proof is
--     recent (15 minutes) via private.require_admin_role(role, true);
--   * every grant and revocation is audited.
--
-- Operations (also in docs/identity-operations.md): bootstrap the first
-- administrator in the SQL editor: insert into public.app_admins and
-- private.admin_roles for their user id, then they enrol TOTP in the app/Auth
-- dashboard and sign in again to obtain aal2. There is no shared admin
-- identity; each person has their own account, phone factor and TOTP factor.

create table private.admin_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('support', 'moderation', 'credential_review', 'infrastructure')),
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);
revoke all on private.admin_roles from public, anon, authenticated;

create function private.audit_admin_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform private.write_audit('admin_role_granted', 'user', new.user_id::text, null, jsonb_build_object('role', new.role));
  else
    perform private.write_audit('admin_role_revoked', 'user', old.user_id::text, null, jsonb_build_object('role', old.role));
  end if;
  return null;
end;
$$;
create trigger admin_roles_audit
  after insert or delete on private.admin_roles
  for each row execute function private.audit_admin_role_change();

-- Is the caller an administrator right now? (RLS policies and many functions
-- call this; the signature is unchanged.)
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.app_admins a where a.user_id = auth.uid())
     and exists (select 1 from private.admin_roles r where r.user_id = auth.uid())
     and coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$$;

create function public.has_admin_role(p_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin()
     and exists (select 1 from private.admin_roles r where r.user_id = auth.uid() and r.role = p_role);
$$;
revoke execute on function public.has_admin_role(text) from public, anon, authenticated;

-- Authorisation gate for privileged functions. Distinguishes "not an
-- administrator / lacks this role" (not_owner) from "right person, session too
-- weak or too old" (reauth_required), the latter only ever shown to someone
-- who already holds the privilege.
create function private.require_admin_role(p_role text, p_recent boolean default true)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_age int;
begin
  if v_uid is null
     or not exists (select 1 from public.app_admins a where a.user_id = v_uid)
     or not exists (select 1 from private.admin_roles r where r.user_id = v_uid and r.role = p_role) then
    raise exception 'not_owner: this action needs the % administrator role', p_role;
  end if;
  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'reauth_required: administrator actions need multi-factor sign-in';
  end if;
  if p_recent then
    v_age := private.auth_age_seconds();
    if v_age is null or v_age > 900 or v_age < -60 then
      raise exception 'reauth_required: confirm with your authenticator before this action';
    end if;
  end if;
end;
$$;
revoke execute on function private.require_admin_role(text, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Role-scoped replacements of existing privileged functions. Bodies are the
-- current definitions with only the authorisation line changed.

create or replace function public.set_city_launch_status(p_city_id text, p_status public.city_launch_status, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.city_launch_status;
begin
  perform private.require_admin_role('infrastructure');
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'validation_failed: a reason is required';
  end if;
  select launch_status into v_old from public.cities where id = p_city_id for update;
  if not found then
    raise exception 'not_found: unknown city';
  end if;
  update public.cities set launch_status = p_status where id = p_city_id;
  perform private.write_audit('city_launch_status_set', 'city', p_city_id, p_reason,
    jsonb_build_object('from', v_old, 'to', p_status));
end;
$$;

create or replace function public.set_category_launch_approval(p_category_id text, p_approved boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old boolean;
begin
  perform private.require_admin_role('infrastructure');
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'validation_failed: a reason is required';
  end if;
  select is_approved_for_launch into v_old from public.service_categories where id = p_category_id for update;
  if not found then
    raise exception 'not_found: unknown category';
  end if;
  update public.service_categories set is_approved_for_launch = p_approved where id = p_category_id;
  perform private.write_audit('category_launch_approval_set', 'service_category', p_category_id, p_reason,
    jsonb_build_object('from', v_old, 'to', p_approved));
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
  perform private.require_admin_role('credential_review');
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

create or replace function public.set_feature_flag(p_key text, p_enabled boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin_role('infrastructure');
  if char_length(btrim(coalesce(p_reason, ''))) not between 3 and 300 then
    raise exception 'validation_failed: a reason (3-300 characters) is required';
  end if;
  insert into public.feature_flags (key, enabled, reason, updated_by, updated_at)
  values (p_key, p_enabled, p_reason, auth.uid(), now())
  on conflict (key) do update set enabled = excluded.enabled, reason = excluded.reason,
    updated_by = excluded.updated_by, updated_at = excluded.updated_at;
  perform private.write_audit('feature_flag_set', 'feature_flag', p_key, p_reason,
    jsonb_build_object('enabled', p_enabled));
end;
$$;

create or replace function public.enforce_profile_mutation_rules()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin boolean := public.is_admin();
begin
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id or new.user_id is distinct from old.user_id then
      raise exception 'not_owner: a listing cannot change owner';
    end if;
    if not (v_admin and public.has_admin_role('moderation')) then
      if new.moderation_status is distinct from old.moderation_status then
        raise exception 'not_owner: only an administrator may change moderation status';
      end if;
      if new.suspension_reason is distinct from old.suspension_reason then
        raise exception 'not_owner: only an administrator may change the suspension reason';
      end if;
    end if;
    -- Phone changes come only from the auth sync trigger (verified OTP).
    if new.phone_e164 is distinct from old.phone_e164 and pg_trigger_depth() < 2 then
      raise exception 'not_owner: phone number changes only through phone verification';
    end if;
    new.created_at := old.created_at;
    new.revision := old.revision + 1;
    new.updated_at := now();
  end if;

  -- WhatsApp is a second channel on the same number: it can never be on while
  -- phone display consent is off.
  new.whatsapp_enabled := new.whatsapp_enabled and new.phone_display_consented;

  -- Withdrawing phone display consent unpublishes the listing (the number is
  -- its only contact channel). It stays paused until the owner consents again
  -- and republishes -- never silently re-listed.
  if tg_op = 'UPDATE' and old.status = 'published' and new.status = 'published' and not new.phone_display_consented then
    new.status := 'paused';
  end if;

  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    if not new.phone_display_consented then
      raise exception 'listing_not_publishable: phone display consent is required to publish';
    end if;
    if new.display_name is null or btrim(new.display_name) = '' then
      raise exception 'validation_failed: display name is required to publish';
    end if;
    if not exists (
      select 1 from auth.users u where u.id = new.user_id and u.phone_confirmed_at is not null
    ) then
      raise exception 'not_authenticated: a verified phone identity is required to publish';
    end if;
    if not exists (select 1 from public.cities c where c.id = new.base_city_id and c.launch_status = 'active') then
      raise exception 'location_not_active: this city is not an active market';
    end if;
    if not exists (
      select 1 from public.provider_categories pc
      join public.service_categories sc on sc.id = pc.category_id
      where pc.provider_id = new.id and sc.is_approved_for_launch
    ) then
      raise exception 'validation_failed: at least one category open for listings is required to publish';
    end if;
    if not exists (select 1 from public.provider_service_areas where provider_id = new.id) then
      raise exception 'validation_failed: at least one service area is required to publish';
    end if;
    if new.moderation_status = 'suspended' then
      raise exception 'suspended: a suspended listing cannot be published';
    end if;
    new.published_at := now();
  elsif tg_op = 'UPDATE' and new.status = 'published' then
    -- Already published: edits must keep it valid.
    if new.display_name is null or btrim(new.display_name) = '' then
      raise exception 'validation_failed: display name is required while published';
    end if;
    new.published_at := old.published_at;
  end if;

  return new;
end;
$$;

-- Grants are unchanged for the replaced functions (create or replace keeps
-- them); restate the ones that were not already explicit.
revoke execute on function public.set_feature_flag(text, boolean, text), public.record_credential_review(uuid, uuid, public.verification_status, text),
  public.set_city_launch_status(text, public.city_launch_status, text), public.set_category_launch_approval(text, boolean, text)
  from public, anon;
grant execute on function public.set_feature_flag(text, boolean, text), public.record_credential_review(uuid, uuid, public.verification_status, text),
  public.set_city_launch_status(text, public.city_launch_status, text), public.set_category_launch_approval(text, boolean, text)
  to authenticated;
