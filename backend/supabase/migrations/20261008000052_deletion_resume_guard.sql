-- 0052: audit follow-up (phase 057).
-- Before: a retry for an existing deletion job needed nothing, so a job left
-- half-done (storage already wiped, auth delete failed) could be completed days
-- later by ANY valid session, even a stolen stale one, without re-authentication;
-- the stored idempotency key was never compared; and there was no way out.
-- Now:
--   * resuming with the same key is free only while the job is fresh (10 min:
--     a dropped response, a double tap). After that it needs a fresh
--     "delete_account" grant, exactly like starting;
--   * a different key than the job's is a conflict (cancel it first);
--   * the owner can cancel an unfinished job (cancel_account_deletion);
--   * account_deletion_status is dropped: it was never called. A retry after
--     success arrives with a token for a user that no longer exists, so the
--     Edge Function answers 401 before any lookup could happen.

create or replace function public.begin_account_deletion(p_user_id uuid, p_idempotency_key text)
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
    if v_job.idempotency_key is distinct from p_idempotency_key then
      raise exception 'conflict: a deletion is already in progress; cancel it before starting another';
    end if;
    if v_job.status <> 'completed' and v_job.updated_at < now() - interval '10 minutes'
       and not private.consume_grant(p_user_id, 'delete_account') then
      raise exception 'reauth_required: confirm with a new code before resuming account deletion';
    end if;
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

-- The signed-in owner abandons an unfinished deletion. Storage that was already
-- removed stays removed (it cannot be restored); the account itself is intact
-- and a new deletion needs a new grant. Needs no grant: it only restores the
-- status quo.
create function public.cancel_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_job private.deletion_jobs;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated: sign in first';
  end if;
  delete from private.deletion_jobs where user_id = auth.uid() and status <> 'completed' returning * into v_job;
  if v_job.id is null then
    return jsonb_build_object('cancelled', false);
  end if;
  perform private.write_audit('account_deletion_cancelled', 'user', auth.uid()::text, null,
    jsonb_build_object('job_id', v_job.id, 'status', v_job.status));
  return jsonb_build_object('cancelled', true);
end;
$$;
revoke execute on function public.cancel_account_deletion() from public, anon;
grant execute on function public.cancel_account_deletion() to authenticated;

drop function public.account_deletion_status(uuid);
