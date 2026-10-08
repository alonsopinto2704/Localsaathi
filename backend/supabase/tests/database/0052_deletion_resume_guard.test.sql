-- Audit follow-up (migration 0052): deletion job resume, key check, owner cancel.
-- Phones +91900052xxxx.
begin;
select plan(13);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('a', tests.create_phone_user('+919000520001')::text),
  ('b', tests.create_phone_user('+919000520002')::text);

select tests.allow_sensitive_action((select value::uuid from fx where key = 'a'), 'delete_account');
set local role service_role;
insert into fx select 'job', (public.begin_account_deletion((select value::uuid from fx where key = 'a'), 'key-aaaaaaaa'))->>'jobId';
select is((public.begin_account_deletion((select value::uuid from fx where key = 'a'), 'key-aaaaaaaa')->>'jobId'),
  (select value from fx where key = 'job'), 'a same-key retry of a fresh job resumes without a new grant');
select throws_like(
  format($sql$ select public.begin_account_deletion(%L::uuid, 'key-other-zz') $sql$, (select value from fx where key = 'a')),
  'conflict%', 'a different idempotency key is refused');
reset role;

-- The job goes stale (user abandoned it, storage possibly already wiped).
update private.deletion_jobs set updated_at = now() - interval '11 minutes', status = 'failed', last_error = 'auth_delete_failed'
  where id = (select value::uuid from fx where key = 'job');
set local role service_role;
select throws_like(
  format($sql$ select public.begin_account_deletion(%L::uuid, 'key-aaaaaaaa') $sql$, (select value from fx where key = 'a')),
  'reauth_required%', 'a stale job cannot be resumed by a bare session (no grant)');
reset role;
select is((select status from private.deletion_jobs where id = (select value::uuid from fx where key = 'job')), 'failed',
  'and it is left untouched');
select tests.allow_sensitive_action((select value::uuid from fx where key = 'a'), 'delete_account');
set local role service_role;
select is((public.begin_account_deletion((select value::uuid from fx where key = 'a'), 'key-aaaaaaaa')->>'status'), 'requested',
  'with a fresh grant the stale job resumes');
reset role;

-- Owner cancel.
select tests.authenticate_as((select value::uuid from fx where key = 'b'));
select is((public.cancel_account_deletion()->>'cancelled')::boolean, false, 'another user has nothing to cancel');
reset role;
select is((select count(*)::int from private.deletion_jobs where user_id = (select value::uuid from fx where key = 'a')), 1,
  'and cannot cancel someone else''s job');
select tests.authenticate_as((select value::uuid from fx where key = 'a'));
select is((public.cancel_account_deletion()->>'cancelled')::boolean, true, 'the owner cancels an unfinished deletion');
select is((public.cancel_account_deletion()->>'cancelled')::boolean, false, 'cancelling twice is harmless');
reset role;
select is((select count(*)::int from private.audit_events where action = 'account_deletion_cancelled'
           and target_id = (select value from fx where key = 'a')), 1, 'the cancellation is audited once');
set local role service_role;
select throws_like(
  format($sql$ select public.begin_account_deletion(%L::uuid, 'key-aaaaaaaa') $sql$, (select value from fx where key = 'a')),
  'reauth_required%', 'after cancelling, starting again needs a new grant');
reset role;

select tests.authenticate_as_anon();
select throws_ok($$ select public.cancel_account_deletion() $$, '42501', null, 'anon cannot call cancel');
reset role;
select is(to_regprocedure('public.account_deletion_status(uuid)') is null, true, 'the never-called receipt lookup is gone');

select * from finish();
rollback;
