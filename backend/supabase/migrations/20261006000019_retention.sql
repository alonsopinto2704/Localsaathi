-- Phase 035: what survives a deletion, for how long, and who can see it.
--
-- Data map (full table in tasks/evidence/phase-035.md):
--   * profile + categories/areas/hours/photos rows/prices/healthcare/consents/
--     verifications/credentials/engagement/promotion interest: deleted with the
--     listing (cascade). Consent history is not kept after deletion: the
--     purpose (showing the number) ended. Revisit with counsel (phase 248).
--   * Storage objects (photos, credential evidence): NOT removed by any SQL
--     cascade. A cleanup row is queued here; delete-account removes the
--     caller's objects before deleting the auth user; queued prefixes from
--     plain listing deletions are processed by the storage lifecycle job
--     (Workstream 5).
--   * Reports about the listing: kept for 180 days with a minimal snapshot so
--     deleting an account cannot erase abuse evidence; admin-only; then purged.
--   * Reporter phone / source hash: nulled after 90 days.
--   * Audit events: kept (append-only); they hold ids and enums, no contact data.
--   * Rate-limit windows: 2 days. Idempotency keys: 24 hours.

alter table public.reports
  drop constraint reports_provider_id_fkey,
  alter column provider_id drop not null,
  add constraint reports_provider_id_fkey foreign key (provider_id)
    references public.provider_profiles(id) on delete set null,
  add column provider_snapshot jsonb;

create table private.storage_cleanup_queue (
  id bigint generated always as identity primary key,
  bucket_id text not null,
  prefix text not null check (prefix ~ '^[0-9a-f-]{36}/$'),
  enqueued_at timestamptz not null default now(),
  processed_at timestamptz,
  unique nulls not distinct (bucket_id, prefix, processed_at)
);
revoke all on private.storage_cleanup_queue from public, anon, authenticated;

create function private.on_provider_profile_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.reports
    set provider_snapshot = jsonb_build_object(
      'displayName', old.display_name, 'baseCityId', old.base_city_id, 'deletedAt', now())
    where provider_id = old.id;

  insert into private.storage_cleanup_queue (bucket_id, prefix)
  select b, old.user_id::text || '/'
  from unnest(array['provider-photos', 'credential-evidence']) b
  on conflict do nothing;

  perform private.write_audit('listing_deleted', 'provider_profile', old.id::text, null,
    jsonb_build_object('by_owner', auth.uid() is not distinct from old.user_id));
  return old;
end;
$$;

create trigger provider_profile_deleted
  before delete on public.provider_profiles
  for each row execute function private.on_provider_profile_deleted();

-- Run daily (Supabase pg_cron or a scheduled Edge Function, service role).
create function private.purge_expired_records()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reports int;
  v_reporter int;
  v_keys int;
  v_limits int;
begin
  delete from public.reports where provider_id is null and created_at < now() - interval '180 days';
  get diagnostics v_reports = row_count;
  update public.reports set reporter_phone_e164 = null, reporter_source = null
    where created_at < now() - interval '90 days' and (reporter_phone_e164 is not null or reporter_source is not null);
  get diagnostics v_reporter = row_count;
  delete from private.idempotency_keys where created_at < now() - interval '24 hours';
  get diagnostics v_keys = row_count;
  delete from private.rate_limits where window_start < now() - interval '2 days';
  get diagnostics v_limits = row_count;
  return jsonb_build_object('reportsDeleted', v_reports, 'reporterFieldsCleared', v_reporter,
                            'idempotencyKeysDeleted', v_keys, 'rateLimitRowsDeleted', v_limits);
end;
$$;

-- Lets delete-account (service role, via PostgREST, hence `public`) mark the
-- caller's queued prefixes done after removing the objects through the
-- Storage API. Not executable by any client role.
create function public.mark_storage_cleaned(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update private.storage_cleanup_queue set processed_at = now()
  where prefix = p_user_id::text || '/' and processed_at is null;
$$;

revoke execute on function private.purge_expired_records(), public.mark_storage_cleaned(uuid),
  private.on_provider_profile_deleted() from public, anon, authenticated;
grant execute on function private.purge_expired_records(), public.mark_storage_cleaned(uuid) to service_role;
