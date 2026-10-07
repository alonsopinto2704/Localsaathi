-- Phases 026 (identity), 027 (publication invariants), 028 (market
-- activation), 030 (revision), 032 (consent withdrawal).
--
-- One predicate decides public eligibility everywhere (public.is_publicly_listed),
-- so a listing that becomes invalid after publication -- consent withdrawn,
-- city deactivated, every category un-approved, suspended -- drops out of every
-- discovery path on the next request, whatever code path changed it.

-- ---------------------------------------------------------------------------
-- 026: phone identity in E.164.
-- GoTrue stores auth.users.phone WITHOUT the leading '+' ('919876543210'), and
-- 0007/0008 copied it verbatim, so real registrations would have produced
-- non-E.164 phone_e164 values that the Dart client and city_requests matching
-- do not expect. Normalise at every entry point and constrain the column.
create function private.normalize_e164(p_raw text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when v ~ '^\+[1-9][0-9]{7,14}$' then v
  end
  from (select '+' || ltrim(regexp_replace(coalesce(p_raw, ''), '[\s()-]', '', 'g'), '+') as v) x;
$$;

-- Backfill rows written by the old register_profile/auth sync (GoTrue format)
-- before constraining; triggers are bypassed because this is a pure format
-- fix, not an owner edit (no revision bump, no publication re-check).
alter table public.provider_profiles disable trigger user;
update public.provider_profiles
  set phone_e164 = private.normalize_e164(phone_e164)
  where phone_e164 !~ '^\+' and private.normalize_e164(phone_e164) is not null;
alter table public.provider_profiles enable trigger user;
update public.consent_records
  set phone_e164 = private.normalize_e164(phone_e164)
  where phone_e164 !~ '^\+' and private.normalize_e164(phone_e164) is not null;

alter table public.provider_profiles
  add constraint provider_phone_is_e164 check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$');

create or replace function public.handle_auth_phone_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := private.normalize_e164(new.phone);
begin
  if new.phone_confirmed_at is null or v_phone is null then
    return new;
  end if;

  if new.phone is distinct from old.phone or new.phone_confirmed_at is distinct from old.phone_confirmed_at then
    update public.provider_profiles
      set phone_e164 = v_phone
      where user_id = new.id and phone_e164 is distinct from v_phone;

    insert into public.verification_records (provider_id, kind, status, method, note)
    select pp.id, 'phone', 'approved', 'otp_sms',
           'Phone control confirmed by one-time code. This says nothing about professional qualifications.'
    from public.provider_profiles pp
    where pp.user_id = new.id and pp.phone_e164 = v_phone;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 030: every committed change to a profile row bumps its revision; writers
-- may pass the revision they started from and get a conflict instead of
-- silently overwriting a newer state (see update_profile_full in 0017).
alter table public.provider_profiles add column revision bigint not null default 1;

-- ---------------------------------------------------------------------------
-- 028: the single public-eligibility rule.
create function public.is_publicly_listed(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.provider_profiles pp
    join public.cities c on c.id = pp.base_city_id
    where pp.id = p_id
      and pp.status = 'published'
      and pp.moderation_status = 'active'
      and pp.phone_display_consented
      and c.launch_status = 'active'
      and exists (
        select 1 from public.provider_categories pc
        join public.service_categories sc on sc.id = pc.category_id
        where pc.provider_id = pp.id and sc.is_approved_for_launch
      )
      and exists (select 1 from public.provider_service_areas sa where sa.provider_id = pp.id)
  );
$$;
revoke execute on function public.is_publicly_listed(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 027 + 032 + 030: the row-level gate, rewritten. SECURITY DEFINER because it
-- reads auth.users (verified identity) whatever role performs the write.
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
    if not v_admin then
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

-- ---------------------------------------------------------------------------
-- 032: consent changes are recorded and applied in one step.
alter table public.consent_records
  add constraint consent_withdrawn_at_only_when_withdrawn check (withdrawn_at is null or not granted);

-- Applies a consent decision to the listing and appends the evidence row.
-- Internal: called by record_consent() and update_profile_full() (0017).
create function private.apply_consent(
  p_profile_id uuid, p_kind public.consent_kind, p_granted boolean, p_wording_version text default 'consent-v1'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text;
  v_phone_consented boolean;
begin
  select phone_e164, phone_display_consented into v_phone, v_phone_consented
  from public.provider_profiles where id = p_profile_id for update;
  if not found then
    raise exception 'not_found: profile not found';
  end if;

  if p_kind = 'display_phone_number' then
    update public.provider_profiles set phone_display_consented = p_granted where id = p_profile_id;
  elsif p_kind = 'whatsapp_contact' then
    if p_granted and not v_phone_consented then
      raise exception 'consent_required: allow your phone number to be shown before enabling WhatsApp';
    end if;
    update public.provider_profiles set whatsapp_enabled = p_granted where id = p_profile_id;
  elsif p_kind = 'public_profile' then
    if not p_granted then
      update public.provider_profiles set status = 'paused' where id = p_profile_id and status = 'published';
    end if;
  elsif p_kind <> 'marketing_contact' then
    -- show_map_location / terms_accepted have dedicated RPCs with their own payloads.
    raise exception 'validation_failed: use the dedicated call for consent kind %', p_kind;
  end if;

  insert into public.consent_records (provider_id, kind, granted, phone_e164, wording_version, withdrawn_at)
  values (p_profile_id, p_kind, p_granted, v_phone, coalesce(nullif(btrim(p_wording_version), ''), 'consent-v1'),
          case when p_granted then null else now() end);
end;
$$;
revoke execute on function private.apply_consent(uuid, public.consent_kind, boolean, text) from public, anon, authenticated;

create function public.record_consent(
  p_profile_id uuid, p_kind public.consent_kind, p_granted boolean, p_wording_version text default 'consent-v1'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.provider_profiles where id = p_profile_id and user_id = auth.uid()) then
    raise exception 'not_owner: cannot record consent for another provider';
  end if;
  if char_length(coalesce(p_wording_version, '')) > 40 then
    raise exception 'validation_failed: wording version too long';
  end if;
  perform private.apply_consent(p_profile_id, p_kind, p_granted, p_wording_version);
  return public.provider_profile_json(p_profile_id);
end;
$$;
revoke execute on function public.record_consent(uuid, public.consent_kind, boolean, text) from public, anon;
grant execute on function public.record_consent(uuid, public.consent_kind, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 028: market activation is an audited admin decision. Direct writes to the
-- reference tables were revoked from API roles in 0013.
create function public.set_city_launch_status(p_city_id text, p_status public.city_launch_status, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.city_launch_status;
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may change market activation';
  end if;
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

create function public.set_category_launch_approval(p_category_id text, p_approved boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old boolean;
begin
  if not public.is_admin() then
    raise exception 'not_owner: only an administrator may change category activation';
  end if;
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
revoke execute on function public.set_city_launch_status(text, public.city_launch_status, text),
  public.set_category_launch_approval(text, boolean, text) from public, anon;
grant execute on function public.set_city_launch_status(text, public.city_launch_status, text),
  public.set_category_launch_approval(text, boolean, text) to authenticated;
