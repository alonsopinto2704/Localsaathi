-- 0029: phase 057, account deletion as an idempotent, auditable job.
--
-- The delete-account Edge Function (service role) is the only caller. It takes
-- the user from the verified JWT, never from the request body, and uses these
-- functions to (1) require a fresh "delete_account" grant (0026), (2) keep ONE
-- deletion state per user so client retries, double taps and dropped responses
-- all converge, and (3) leave a minimal receipt after the account is gone.
--
-- The job row deliberately has no foreign key to auth.users: it must outlive
-- the user. It stores the user id and timestamps only: no phone number, name or
-- listing data. Rows are purged after 30 days (public.purge_deletion_jobs).

create table private.deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  idempotency_key text not null check (idempotency_key ~ '^[A-Za-z0-9_-]{8,64}$'),
  status text not null default 'requested' check (status in ('requested', 'storage_cleaned', 'completed', 'failed')),
  attempts int not null default 1,
  last_error text check (last_error is null or last_error ~ '^[a-z_]{1,40}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);
revoke all on private.deletion_jobs from public, anon, authenticated;

-- Starts (or resumes) the deletion for p_user_id. The first call consumes the
-- recent-authentication grant; a retry for an existing job needs none, so a
-- dropped response never strands a user mid-deletion.
create function public.begin_account_deletion(p_user_id uuid, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job private.deletion_jobs;
begin
  if p_idempotency_key is null or p_idempotency_key !~ '^[A-Za-z0-9_-]{8,64}$' then
    raise exception 'validation_failed: idempotency key must be 8-64 URL-safe characters';
  end if;
  select * into v_job from private.deletion_jobs where user_id = p_user_id for update;
  if v_job.id is not null then
    update private.deletion_jobs
      set attempts = attempts + 1, updated_at = now(),
          status = case when status = 'failed' then 'requested' else status end
      where id = v_job.id returning * into v_job;
    return jsonb_build_object('jobId', v_job.id, 'status', v_job.status, 'resumed', true);
  end if;
  if not private.consume_grant(p_user_id, 'delete_account') then
    raise exception 'reauth_required: confirm with a new code before deleting your account';
  end if;
  insert into private.deletion_jobs (user_id, idempotency_key) values (p_user_id, p_idempotency_key)
    returning * into v_job;
  perform private.write_audit('account_deletion_requested', 'user', p_user_id::text, null,
    jsonb_build_object('job_id', v_job.id));
  return jsonb_build_object('jobId', v_job.id, 'status', v_job.status, 'resumed', false);
end;
$$;

create function public.advance_account_deletion(p_job_id uuid, p_status text, p_error text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_status not in ('storage_cleaned', 'completed', 'failed') then
    raise exception 'validation_failed: unknown deletion status';
  end if;
  update private.deletion_jobs
    set status = p_status, last_error = case when p_status = 'failed' then p_error else null end,
        updated_at = now(), completed_at = case when p_status = 'completed' then now() end
    where id = p_job_id and status <> 'completed';
  if not found then
    raise exception 'not_found: deletion job not found or already completed';
  end if;
  if p_status = 'completed' then
    perform private.write_audit('account_deletion_completed', 'user',
      (select user_id::text from private.deletion_jobs where id = p_job_id), null,
      jsonb_build_object('job_id', p_job_id));
  end if;
end;
$$;

-- Receipt lookup for the Edge Function (e.g. a retry arriving after success).
create function public.account_deletion_status(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select jsonb_build_object('jobId', id, 'status', status) from private.deletion_jobs where user_id = p_user_id), 'null'::jsonb);
$$;

create function public.purge_deletion_jobs(p_now timestamptz default now())
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n int;
begin
  delete from private.deletion_jobs where status = 'completed' and completed_at < p_now - interval '30 days';
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke execute on function public.begin_account_deletion(uuid, text), public.advance_account_deletion(uuid, text, text),
  public.account_deletion_status(uuid), public.purge_deletion_jobs(timestamptz) from public, anon, authenticated;
grant execute on function public.begin_account_deletion(uuid, text), public.advance_account_deletion(uuid, text, text),
  public.account_deletion_status(uuid), public.purge_deletion_jobs(timestamptz) to service_role;
