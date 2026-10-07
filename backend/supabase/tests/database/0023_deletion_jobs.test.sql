-- Phase 057 (migration 0029): account deletion jobs. Phones +91900023xxxx.
begin;
select plan(17);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('a', tests.create_phone_user('+919000230001')::text),
  ('b', tests.create_phone_user('+919000230002')::text);

set local role service_role;
select throws_like(
  format($sql$ select public.begin_account_deletion(%L::uuid, 'key-aaaaaaaa') $sql$, (select value from fx where key = 'a')),
  'reauth_required%', 'no recent-authentication grant: no deletion starts');
select throws_like(
  format($sql$ select public.begin_account_deletion(%L::uuid, 'short') $sql$, (select value from fx where key = 'a')),
  'validation_failed%', 'a malformed idempotency key is refused');
reset role;

select tests.allow_sensitive_action((select value::uuid from fx where key = 'a'), 'delete_account');
set local role service_role;
insert into fx select 'job', (public.begin_account_deletion((select value::uuid from fx where key = 'a'), 'key-aaaaaaaa'))::text;
select is(((select value::jsonb from fx where key = 'job')->>'resumed')::boolean, false, 'the first request creates the job');
select is(((select value::jsonb from fx where key = 'job')->>'status'), 'requested', 'in the requested state');
select is((public.begin_account_deletion((select value::uuid from fx where key = 'a'), 'key-aaaaaaaa')->>'jobId'),
  ((select value::jsonb from fx where key = 'job')->>'jobId'), 'a retry with the same key returns the same job without a new grant');
select is((public.begin_account_deletion((select value::uuid from fx where key = 'a'), 'a-different-key')->>'jobId'),
  ((select value::jsonb from fx where key = 'job')->>'jobId'), 'even a different key converges on the one deletion state');
select throws_like(
  format($sql$ select public.begin_account_deletion(%L::uuid, 'key-bbbbbbbb') $sql$, (select value from fx where key = 'b')),
  'reauth_required%', 'another account''s grant never authorises this one (cross-account attempts fail)');
reset role;
select is((select attempts from private.deletion_jobs where user_id = (select value::uuid from fx where key = 'a')), 3,
  'attempts are counted, one row exists');

set local role service_role;
select throws_like(
  format($sql$ select public.advance_account_deletion(%L::uuid, 'exploded') $sql$, (select value::jsonb->>'jobId' from fx where key = 'job')),
  'validation_failed%', 'only known statuses are accepted');
select throws_ok(
  format($sql$ select public.advance_account_deletion(%L::uuid, 'failed', 'secret detail 12345') $sql$, (select value::jsonb->>'jobId' from fx where key = 'job')),
  '23514', null, 'a failure records a short code only, never free text');
select public.advance_account_deletion((select (value::jsonb->>'jobId')::uuid from fx where key = 'job'), 'failed', 'storage_cleanup_failed');
select is((public.begin_account_deletion((select value::uuid from fx where key = 'a'), 'key-aaaaaaaa')->>'status'), 'requested',
  'retrying a failed job resumes it');
select public.advance_account_deletion((select (value::jsonb->>'jobId')::uuid from fx where key = 'job'), 'storage_cleaned');
select public.advance_account_deletion((select (value::jsonb->>'jobId')::uuid from fx where key = 'job'), 'completed');
select throws_like(
  format($sql$ select public.advance_account_deletion(%L::uuid, 'failed', 'late_error') $sql$, (select value::jsonb->>'jobId' from fx where key = 'job')),
  'not_found%', 'a completed job never goes backwards');
select is((public.account_deletion_status((select value::uuid from fx where key = 'a'))->>'status'), 'completed', 'the receipt reads completed');
select is(public.account_deletion_status(gen_random_uuid()), 'null'::jsonb, 'unknown users have no receipt');
reset role;

select is((select count(*)::int from private.audit_events where action in ('account_deletion_requested', 'account_deletion_completed')
           and target_id = (select value from fx where key = 'a')), 2, 'request and completion are each audited once, without a number');

update private.deletion_jobs set completed_at = now() - interval '31 days' where status = 'completed';
set local role service_role;
select is(public.purge_deletion_jobs(), 1, 'receipts are purged after 30 days');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'a'));
select throws_ok(
  format($sql$ select public.begin_account_deletion(%L::uuid, 'key-aaaaaaaa') $sql$, (select value from fx where key = 'b')),
  '42501', null, 'a signed-in user cannot start a deletion for anyone, themselves included, through the API');
reset role;

select * from finish();
rollback;
