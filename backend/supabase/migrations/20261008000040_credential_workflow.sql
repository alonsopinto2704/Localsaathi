-- 0040: phases 088 (private credential intake) and 089 (credential decision workflow).
--
-- Before: a provider's credential claim sat in credential_records as 'pending'
-- and any administrator (any role, support included) could read the row and the
-- evidence file, and record_credential_review() flipped it to approved with a
-- free-text note: no source reference, no validity period, no reviewer claim,
-- no expiry, no record of who looked at the evidence.
--
-- After:
--   * States: submitted -> reviewing -> needs_information | approved | rejected,
--     and approved -> expired (or withdrawn back to submitted). Only a person
--     holding the credential_review role, on an aal2 session, can move a case,
--     and never their own listing's case.
--   * An approval needs a source type (registry/document), a source reference,
--     a rationale and a validity period (max 3 years, never beyond the date the
--     provider claimed). Healthcare categories need a registry check.
--   * Every decision is an attributable, append-only row in
--     private.credential_decisions; the public badge (0041) is derived from the
--     current, unwithdrawn, unexpired decision, never from a status flag.
--   * Evidence bytes live in the private bucket 'credentials-private' (created
--     by the storage workstream, phases 081-087; this migration only names it).
--     Nobody except the owner may read the bucket through RLS. A reviewer gets a
--     60-second signed URL from an Edge Function that first calls
--     begin_credential_evidence_view(), which checks role + MFA + a claimed
--     case, rate-limits and logs the access. Support/moderation roles get
--     nothing: the old "admins may read any evidence" storage policy is removed.
--   * AI cannot grant a credential: there is no function a service account or
--     model can call; decisions require an authenticated human reviewer id.

-- ---------------------------------------------------------------------------
-- Intake columns.
alter table public.credential_records
  add column review_state text not null default 'submitted'
    check (review_state in ('submitted', 'reviewing', 'needs_information', 'approved', 'rejected', 'expired')),
  add column evidence_bucket text not null default 'credentials-private'
    check (evidence_bucket in ('credentials-private', 'credential-evidence')),
  add column notice_version text,
  add column notice_acknowledged_at timestamptz,
  add column submitted_at timestamptz not null default now(),
  add column reviewer_id uuid references auth.users(id) on delete set null,
  add column current_decision_id uuid,
  add column note_to_provider text check (char_length(note_to_provider) <= 500);

-- Rows created before this migration used the old bucket and carry no
-- attributable decision, so an old 'approved' is not a badge any more: it goes
-- back to the queue.
update public.credential_records set evidence_bucket = 'credential-evidence' where evidence_storage_path is not null;
update public.credential_records
  set review_state = case when status = 'rejected' then 'rejected' else 'submitted' end,
      status = case when status = 'approved' then 'pending'::public.verification_status else status end;

grant insert (notice_version) on public.credential_records to authenticated;

-- Reviewer access is by function, not by table or bucket policy.
drop policy "owner reads own credentials" on public.credential_records;
create policy "owner reads own credentials" on public.credential_records for select using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid())
);
drop policy "owner removes own claimed credential" on public.credential_records;
create policy "owner removes own credential" on public.credential_records for delete using (
  exists (select 1 from public.provider_profiles pp where pp.id = provider_id and pp.user_id = auth.uid())
);
drop policy "owner reads own credential evidence" on storage.objects;
create policy "owner reads own credential evidence" on storage.objects for select
  using (bucket_id = 'credential-evidence' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------------
-- Decisions (append-only) and the evidence-access log.
create table private.credential_decisions (
  id uuid primary key default gen_random_uuid(),
  credential_id uuid not null references public.credential_records(id) on delete cascade,
  provider_id uuid not null,
  decision text not null check (decision in ('approved', 'rejected', 'needs_information')),
  reviewer_id uuid not null references auth.users(id),
  source_type text check (source_type in ('registry', 'document', 'registry_and_document')),
  source_reference text check (char_length(source_reference) between 3 and 300),
  rationale text not null check (char_length(btrim(rationale)) between 10 and 1000),
  valid_from date,
  valid_until date,
  created_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  withdrawn_by uuid references auth.users(id),
  withdraw_reason text check (char_length(withdraw_reason) between 5 and 300),
  check (decision <> 'approved' or (
    source_type is not null and source_reference is not null
    and valid_from is not null and valid_until > valid_from and valid_until <= valid_from + 1096)),
  check ((withdrawn_at is null) = (withdrawn_by is null))
);
create index credential_decisions_credential on private.credential_decisions (credential_id, created_at desc);
revoke all on private.credential_decisions from public, anon, authenticated;

create table private.credential_access_log (
  id bigint generated always as identity primary key,
  credential_id uuid not null references public.credential_records(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id),
  reason text not null,
  created_at timestamptz not null default now()
);
revoke all on private.credential_access_log from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Intake guard. A claim always starts as 'submitted' whoever inserts it, and an
-- upload needs the provider to have accepted the current evidence notice
-- (purpose, requested fields, who may see it, retention; the wording is
-- client-side, docs/trust-and-credentials.md section 1 fixes the content).
create function private.credential_intake()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    new.review_state := 'submitted';
    new.reviewer_id := null;
    new.current_decision_id := null;
    new.note_to_provider := null;
    new.submitted_at := now();
    new.evidence_bucket := 'credentials-private';
    if new.evidence_storage_path is not null and new.notice_version is distinct from 'credential-notice-v1' then
      raise exception 'consent_required: read and accept the credential evidence notice before uploading';
    end if;
  end if;
  new.notice_acknowledged_at := case when new.notice_version is not null then now() end;
  return new;
end;
$$;
create trigger trg_credential_intake
  before insert on public.credential_records
  for each row execute function private.credential_intake();

-- Per-object cleanup now follows the row's own bucket.
drop trigger trg_queue_credential_cleanup on public.credential_records;
create function private.queue_credential_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.evidence_storage_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}$' then
    insert into private.storage_cleanup_queue (bucket_id, prefix) values (old.evidence_bucket, old.evidence_storage_path)
    on conflict do nothing;
  end if;
  return old;
end;
$$;
create trigger trg_queue_credential_cleanup after delete on public.credential_records
  for each row execute function private.queue_credential_cleanup();

-- ---------------------------------------------------------------------------
-- Reviewer workflow.
create function public.list_credential_queue(p_limit int default 25)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin_role('credential_review', false);
  return coalesce((
    select jsonb_agg(x.j order by x.submitted_at) from (
      select cr.submitted_at, jsonb_build_object(
          'credentialId', cr.id, 'providerId', cr.provider_id, 'title', cr.title,
          'issuingBody', cr.issuing_body, 'state', cr.review_state, 'submittedAt', cr.submitted_at,
          'hasEvidence', cr.evidence_storage_path is not null, 'mine', cr.reviewer_id = auth.uid()) as j
      from public.credential_records cr
      join public.provider_profiles pp on pp.id = cr.provider_id
      where pp.user_id <> auth.uid()
        and (cr.review_state = 'submitted' or (cr.review_state = 'reviewing' and cr.reviewer_id = auth.uid()))
      order by cr.submitted_at
      limit least(greatest(coalesce(p_limit, 25), 1), 100)
    ) x), '[]'::jsonb);
end;
$$;

-- Claims a submitted case (or re-reads one the caller already holds) and
-- returns what a reviewer needs to check against the source. No evidence path.
create function public.start_credential_review(p_credential_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_c public.credential_records;
begin
  perform private.require_admin_role('credential_review', false);
  select * into v_c from public.credential_records where id = p_credential_id for update;
  if not found then
    raise exception 'not_found: credential not found';
  end if;
  if exists (select 1 from public.provider_profiles pp where pp.id = v_c.provider_id and pp.user_id = auth.uid()) then
    raise exception 'not_owner: you cannot review your own credential';
  end if;
  if v_c.review_state = 'submitted' then
    update public.credential_records set review_state = 'reviewing', reviewer_id = auth.uid()
      where id = v_c.id returning * into v_c;
    perform private.write_audit('credential_review_started', 'credential_record', v_c.id::text, null,
      jsonb_build_object('provider_id', v_c.provider_id));
  elsif not (v_c.review_state in ('reviewing', 'needs_information') and v_c.reviewer_id = auth.uid()) then
    raise exception 'conflict: this credential is not waiting for you';
  end if;
  return jsonb_build_object(
    'credentialId', v_c.id, 'providerId', v_c.provider_id, 'state', v_c.review_state,
    'title', v_c.title, 'issuingBody', v_c.issuing_body, 'registrationNumber', v_c.registration_number,
    'claimedValidUntil', v_c.valid_until, 'hasEvidence', v_c.evidence_storage_path is not null,
    'healthcare', exists (select 1 from public.provider_categories pc
                          join public.service_categories sc on sc.id = pc.category_id
                          where pc.provider_id = v_c.provider_id and sc.is_healthcare));
end;
$$;

-- Step 1 of reading evidence bytes. The Edge Function calls this with the
-- reviewer's own JWT; only on success does it (service role) sign `path` in
-- `bucket` for `ttlSeconds` and return that URL. The URL must never be logged.
create function public.begin_credential_evidence_view(p_credential_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_c public.credential_records;
begin
  perform private.require_admin_role('credential_review', true);
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 200 then
    raise exception 'validation_failed: say why you are opening the evidence (5-200 characters)';
  end if;
  select * into v_c from public.credential_records where id = p_credential_id for update;
  if not found or v_c.evidence_storage_path is null then
    raise exception 'not_found: no evidence for this credential';
  end if;
  if exists (select 1 from public.provider_profiles pp where pp.id = v_c.provider_id and pp.user_id = auth.uid()) then
    raise exception 'not_owner: you cannot review your own credential';
  end if;
  if v_c.reviewer_id is distinct from auth.uid() or v_c.review_state not in ('reviewing', 'needs_information') then
    raise exception 'not_owner: claim this case before opening its evidence';
  end if;
  if not private.take_rate_token('credential:view', auth.uid()::text, interval '1 hour', 60) then
    raise exception 'rate_limited: too many evidence views this hour';
  end if;
  insert into private.credential_access_log (credential_id, reviewer_id, reason)
  values (v_c.id, auth.uid(), btrim(p_reason));
  perform private.write_audit('credential_evidence_viewed', 'credential_record', v_c.id::text, null,
    jsonb_build_object('provider_id', v_c.provider_id));
  return jsonb_build_object('bucket', v_c.evidence_bucket, 'path', v_c.evidence_storage_path, 'ttlSeconds', 60);
end;
$$;

create function public.decide_credential(
  p_credential_id uuid, p_decision text, p_rationale text,
  p_source_type text default null, p_source_reference text default null,
  p_valid_until date default null, p_note_to_provider text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_c public.credential_records;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
  v_id uuid;
begin
  perform private.require_admin_role('credential_review', true);
  if p_decision is null or p_decision not in ('approved', 'rejected', 'needs_information') then
    raise exception 'validation_failed: decision must be approved, rejected or needs_information';
  end if;
  if char_length(btrim(coalesce(p_rationale, ''))) not between 10 and 1000 then
    raise exception 'validation_failed: a rationale (10-1000 characters) is required';
  end if;
  select * into v_c from public.credential_records where id = p_credential_id for update;
  if not found then
    raise exception 'not_found: credential not found';
  end if;
  if exists (select 1 from public.provider_profiles pp where pp.id = v_c.provider_id and pp.user_id = auth.uid()) then
    raise exception 'not_owner: you cannot decide your own credential';
  end if;
  if v_c.review_state <> 'reviewing' or v_c.reviewer_id is distinct from auth.uid() then
    raise exception 'conflict: claim this case (start_credential_review) before deciding it';
  end if;
  if p_decision = 'approved' then
    if p_source_type is null or p_source_type not in ('registry', 'document', 'registry_and_document')
       or char_length(btrim(coalesce(p_source_reference, ''))) not between 3 and 300 then
      raise exception 'validation_failed: an approval needs a source type and a source reference';
    end if;
    if p_valid_until is null or p_valid_until <= v_today or p_valid_until > v_today + 1096 then
      raise exception 'validation_failed: validity must end after today and within 3 years';
    end if;
    if v_c.valid_until is not null and p_valid_until > v_c.valid_until then
      raise exception 'validation_failed: validity cannot outlast the date the provider claimed';
    end if;
    if p_source_type = 'document' and exists (
         select 1 from public.provider_categories pc join public.service_categories sc on sc.id = pc.category_id
         where pc.provider_id = v_c.provider_id and sc.is_healthcare) then
      raise exception 'validation_failed: healthcare credentials need a registry check, not a document alone';
    end if;
  elsif p_decision = 'needs_information' and char_length(btrim(coalesce(p_note_to_provider, ''))) not between 5 and 500 then
    raise exception 'validation_failed: tell the provider what is missing (5-500 characters)';
  end if;

  insert into private.credential_decisions (credential_id, provider_id, decision, reviewer_id, source_type,
    source_reference, rationale, valid_from, valid_until)
  values (v_c.id, v_c.provider_id, p_decision, auth.uid(),
    case when p_decision = 'approved' then p_source_type end,
    case when p_decision = 'approved' then btrim(p_source_reference) end,
    btrim(p_rationale),
    case when p_decision = 'approved' then v_today end,
    case when p_decision = 'approved' then p_valid_until end)
  returning id into v_id;

  update public.credential_records set
    review_state = p_decision,
    status = case p_decision when 'approved' then 'approved' when 'rejected' then 'rejected' else 'pending' end::public.verification_status,
    reviewed_at = now(), reviewed_by = auth.uid(), current_decision_id = v_id,
    note_to_provider = case when p_decision <> 'approved' then nullif(btrim(p_note_to_provider), '') end
  where id = v_c.id;

  if p_decision <> 'needs_information' then
    insert into public.verification_records (provider_id, kind, status, method, reviewed_by, reviewed_at)
    values (v_c.provider_id, 'credentials', p_decision::public.verification_status, 'document_review', auth.uid(), now());
  end if;
  perform private.write_audit('credential_decided', 'credential_record', v_c.id::text, null,
    jsonb_build_object('provider_id', v_c.provider_id, 'decision', p_decision, 'decision_id', v_id));
  return jsonb_build_object('credentialId', v_c.id, 'decisionId', v_id, 'state', p_decision);
end;
$$;

-- A disputed badge comes down immediately and the case returns to the queue.
create function public.withdraw_credential_decision(p_credential_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_c public.credential_records;
begin
  perform private.require_admin_role('credential_review', true);
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 300 then
    raise exception 'validation_failed: a reason (5-300 characters) is required';
  end if;
  select * into v_c from public.credential_records where id = p_credential_id for update;
  if not found then
    raise exception 'not_found: credential not found';
  end if;
  if exists (select 1 from public.provider_profiles pp where pp.id = v_c.provider_id and pp.user_id = auth.uid()) then
    raise exception 'not_owner: you cannot act on your own credential';
  end if;
  if v_c.review_state <> 'approved' then
    raise exception 'conflict: only an approved credential can be withdrawn';
  end if;
  update private.credential_decisions set withdrawn_at = now(), withdrawn_by = auth.uid(), withdraw_reason = btrim(p_reason)
    where id = v_c.current_decision_id;
  update public.credential_records set review_state = 'submitted', status = 'pending', reviewer_id = null,
    note_to_provider = null where id = v_c.id;
  insert into public.verification_records (provider_id, kind, status, method, reviewed_by, reviewed_at)
  values (v_c.provider_id, 'credentials', 'pending', 'document_review', auth.uid(), now());
  perform private.write_audit('credential_withdrawn', 'credential_record', v_c.id::text, null,
    jsonb_build_object('provider_id', v_c.provider_id, 'decision_id', v_c.current_decision_id));
  return jsonb_build_object('credentialId', v_c.id, 'state', 'submitted');
end;
$$;

-- Scheduled (service role). The public badge already ignores a lapsed decision
-- by date, so a late run only delays the owner-facing state.
create function public.expire_credential_decisions()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n int;
begin
  with e as (
    update public.credential_records cr set review_state = 'expired', status = 'pending'
    from private.credential_decisions d
    where d.id = cr.current_decision_id and cr.review_state = 'approved'
      and d.valid_until < (now() at time zone 'Asia/Kolkata')::date
    returning cr.provider_id
  ), v as (
    insert into public.verification_records (provider_id, kind, status, method)
    select provider_id, 'credentials', 'pending', 'document_review' from e returning 1
  )
  select count(*) into v_n from e;
  if v_n > 0 then
    perform private.write_audit('credentials_expired', 'credential_record', 'batch', null, jsonb_build_object('count', v_n));
  end if;
  return v_n;
end;
$$;

-- Rejected and expired evidence is not kept: 90 days after the last decision
-- the file is queued for deletion and the path cleared (approved evidence stays
-- for the validity period; the owner can delete a credential at any time).
create function public.purge_stale_credential_evidence()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n int;
begin
  with t as (
    select id, evidence_bucket b, evidence_storage_path p from public.credential_records
    where evidence_storage_path is not null and review_state in ('rejected', 'expired')
      and reviewed_at < now() - interval '90 days'
    for update
  ), q as (
    insert into private.storage_cleanup_queue (bucket_id, prefix)
    select b, p from t where p ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}$'
    on conflict do nothing
  ), u as (
    update public.credential_records c set evidence_storage_path = null from t where c.id = t.id returning 1
  )
  select count(*) into v_n from u;
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- Provider side.
create function public.get_credential_status(p_provider_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.provider_profiles pp where pp.id = p_provider_id and pp.user_id = auth.uid()) then
    raise exception 'not_owner: not your listing';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
        'credentialId', cr.id, 'title', cr.title, 'state',
        case when cr.review_state = 'approved' and d.valid_until < (now() at time zone 'Asia/Kolkata')::date
             then 'expired' else cr.review_state end,
        'noteToProvider', cr.note_to_provider, 'validUntil', d.valid_until, 'submittedAt', cr.submitted_at)
      order by cr.submitted_at)
    from public.credential_records cr
    left join private.credential_decisions d on d.id = cr.current_decision_id and d.decision = 'approved' and d.withdrawn_at is null
    where cr.provider_id = p_provider_id), '[]'::jsonb);
end;
$$;

-- After "needs information", a rejection, or expiry: send it back for review,
-- optionally with a replacement file (the old file is queued for deletion).
create function public.resubmit_credential(p_credential_id uuid, p_evidence_path text default null, p_notice_version text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_c public.credential_records;
  v_uid uuid := auth.uid();
begin
  perform private.require_flag('credential_intake');
  select cr.* into v_c from public.credential_records cr
    join public.provider_profiles pp on pp.id = cr.provider_id
    where cr.id = p_credential_id and pp.user_id = v_uid for update of cr;
  if not found then
    raise exception 'not_owner: not your credential';
  end if;
  if v_c.review_state not in ('needs_information', 'rejected', 'expired') then
    raise exception 'conflict: this credential cannot be resubmitted now';
  end if;
  if p_evidence_path is not null then
    if p_evidence_path !~ ('^' || v_uid::text || '/[A-Za-z0-9._-]{1,100}$') then
      raise exception 'validation_failed: evidence must be uploaded to your own folder';
    end if;
    if p_notice_version is distinct from 'credential-notice-v1' then
      raise exception 'consent_required: read and accept the credential evidence notice before uploading';
    end if;
  end if;
  if not private.take_rate_token('credential:resubmit', v_uid::text, interval '1 day', 10) then
    raise exception 'rate_limited: too many resubmissions today';
  end if;
  if p_evidence_path is not null and v_c.evidence_storage_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}$'
     and v_c.evidence_storage_path <> p_evidence_path then
    insert into private.storage_cleanup_queue (bucket_id, prefix) values (v_c.evidence_bucket, v_c.evidence_storage_path)
    on conflict do nothing;
  end if;
  update public.credential_records set
    review_state = 'submitted', status = 'pending', reviewer_id = null, note_to_provider = null,
    submitted_at = now(),
    evidence_storage_path = coalesce(p_evidence_path, evidence_storage_path),
    evidence_bucket = case when p_evidence_path is not null then 'credentials-private' else evidence_bucket end,
    notice_version = coalesce(p_notice_version, notice_version),
    notice_acknowledged_at = case when p_notice_version is not null then now() else notice_acknowledged_at end
  where id = v_c.id;
  return jsonb_build_object('credentialId', v_c.id, 'state', 'submitted');
end;
$$;

-- The old one-step review is gone: it recorded no source, rationale or validity.
-- The signature and role gate stay so existing callers get a clear error.
create or replace function public.record_credential_review(
  p_provider_id uuid, p_credential_id uuid, p_status public.verification_status, p_note text default null
)
returns public.credential_records
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin_role('credential_review');
  raise exception 'validation_failed: use start_credential_review and decide_credential (source reference, rationale and validity are required)';
end;
$$;

revoke execute on function
  public.list_credential_queue(int), public.start_credential_review(uuid),
  public.begin_credential_evidence_view(uuid, text),
  public.decide_credential(uuid, text, text, text, text, date, text),
  public.withdraw_credential_decision(uuid, text), public.expire_credential_decisions(),
  public.purge_stale_credential_evidence(), public.get_credential_status(uuid),
  public.resubmit_credential(uuid, text, text), private.credential_intake(), private.queue_credential_cleanup()
  from public, anon, authenticated;
grant execute on function
  public.list_credential_queue(int), public.start_credential_review(uuid),
  public.begin_credential_evidence_view(uuid, text),
  public.decide_credential(uuid, text, text, text, text, date, text),
  public.withdraw_credential_decision(uuid, text), public.get_credential_status(uuid),
  public.resubmit_credential(uuid, text, text)
  to authenticated;
grant execute on function public.expire_credential_decisions(), public.purge_stale_credential_evidence() to service_role;
