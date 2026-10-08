-- Phase 053 (migration 0028): SIM-loss recovery. Phones +91900022xxxx.
begin;
select plan(27);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('owner', tests.create_phone_user('+919000220001')::text),       -- the real owner (lost SIM)
  ('claimant', tests.create_phone_user('+919000220002')::text),    -- new number, no listing
  ('attacker', tests.create_phone_user('+919000220003')::text),    -- has a listing of their own
  ('admin', tests.create_admin('+919000220009')::text),
  ('admin2', tests.create_admin('+919000220010')::text);   -- executor: must differ from the approving reviewer
insert into fx select 'p', tests.create_published_provider((select value::uuid from fx where key = 'owner'), '+919000220001', 'Recovery Listing')::text;
insert into fx select 'pa', tests.create_published_provider((select value::uuid from fx where key = 'attacker'), '+919000220003', 'Attacker Listing')::text;
insert into auth.sessions (user_id) values ((select value::uuid from fx where key = 'owner')), ((select value::uuid from fx where key = 'owner'));

-- 1. Opening a case.
select tests.authenticate_as((select value::uuid from fx where key = 'claimant'));
select throws_like(
  format($sql$ select public.open_recovery_case(%L::uuid, 'I own it, my number is 9000220002 now please') $sql$, (select value from fx where key = 'p')),
  'validation_failed%', 'a statement containing a phone number is refused');
select throws_like(
  format($sql$ select public.open_recovery_case(%L::uuid, 'short') $sql$, (select value from fx where key = 'p')),
  'validation_failed%', 'a one-word statement is refused');
select throws_like(
  $$ select public.open_recovery_case(gen_random_uuid(), 'I run this business from the Andheri shop and lost my SIM') $$,
  'not_found%', 'an unknown listing is not found');
insert into fx select 'resp1', (public.open_recovery_case((select value::uuid from fx where key = 'p'),
  'I run this business from the Andheri shop and lost my SIM'))::text;
insert into fx select 'case1', (value::jsonb)->>'caseId' from fx where key = 'resp1';
reset role;
select is((select count(*)::int from private.recovery_cases where id = (select value::uuid from fx where key = 'case1')), 1, 'a verified new number can open a case');

select is(
  (select array_agg(k order by k) from jsonb_object_keys((select value::jsonb from fx where key = 'resp1')) k),
  array['caseId', 'status'], 'the response reveals nothing about the listing');
select tests.authenticate_as((select value::uuid from fx where key = 'attacker'));
select throws_like(
  format($sql$ select public.open_recovery_case(%L::uuid, 'I run this business from the Andheri shop and lost my SIM') $sql$, (select value from fx where key = 'p')),
  'conflict%', 'an account that already has a listing cannot claim another');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select throws_like(
  format($sql$ select public.open_recovery_case(%L::uuid, 'I run this business from the Andheri shop and lost my SIM') $sql$, (select value from fx where key = 'p')),
  'conflict%', 'the owner cannot open a recovery against their own listing');
reset role;
select tests.authenticate_as_anon();
select throws_ok($$ select public.open_recovery_case(gen_random_uuid(), 'I run this business from the Andheri shop') $$, '42501', null, 'anon cannot open a case');
reset role;

-- 2. Public knowledge does not move anything: only an administrator decides.
select tests.authenticate_as((select value::uuid from fx where key = 'claimant'));
select throws_like(
  format($sql$ select public.admin_review_recovery_case(%L::uuid, 'approve', 'The claimant knows the listing details well') $sql$, (select value from fx where key = 'case1')),
  'not_owner%', 'the claimant cannot approve their own case');
select throws_like(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case1')),
  'not_owner%', 'the claimant cannot execute a transfer');
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin'));
select throws_like(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case1')),
  'conflict%', 'an unapproved case cannot be carried out');
select throws_like(
  format($sql$ select public.admin_review_recovery_case(%L::uuid, 'approve', 'ok') $sql$, (select value from fx where key = 'case1')),
  'validation_failed%', 'a decision needs a written rationale');
select public.admin_review_recovery_case((select value::uuid from fx where key = 'case1'), 'approve',
  'Called the business landline listed on a past invoice and the owner confirmed the SIM was lost.');
reset role;
select ok((select eligible_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 hour'
           from private.recovery_cases where id = (select value::uuid from fx where key = 'case1')),
  'approval starts a 7-day waiting period');
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin2'));
select throws_like(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case1')),
  'conflict%', 'nothing happens during the waiting period, even for an administrator');
select is((select jsonb_array_length(public.admin_recovery_queue())), 1, 'support sees the case in the queue');
select is((select (public.admin_recovery_queue()->0)->>'claimantPhoneEnding'), '02', 'the queue shows only the last digits of the claimant number');
reset role;

-- 3. The existing owner can still stop it.
select tests.authenticate_as((select value::uuid from fx where key = 'owner'));
select is(jsonb_array_length(public.my_recovery_notices()), 1, 'the owner sees that a request exists');
select is((select array_agg(k order by k) from jsonb_object_keys(public.my_recovery_notices()->0) k),
  array['caseId', 'eligibleAt', 'openedAt', 'status'], 'and learns nothing about the claimant');
select public.dispute_recovery_case((select value::uuid from fx where key = 'case1'));
reset role;
update private.recovery_cases set eligible_at = now() - interval '1 minute' where id = (select value::uuid from fx where key = 'case1');
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin'));
select throws_like(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case1')),
  'conflict%', 'a disputed (frozen) case cannot be carried out even after the waiting period');
reset role;

-- 4. Happy path with a second, undisputed case.
select tests.authenticate_as((select value::uuid from fx where key = 'claimant'));
insert into fx select 'case2', (public.open_recovery_case((select value::uuid from fx where key = 'p'),
  'I run this business from the Andheri shop and lost my SIM, new number is mine'))->>'caseId';
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin'));
select public.admin_review_recovery_case((select value::uuid from fx where key = 'case2'), 'approve',
  'Second request after the first was disputed; owner could not be reached and the dispute lapsed after review.');
reset role;
update private.recovery_cases set eligible_at = now() - interval '1 minute' where id = (select value::uuid from fx where key = 'case2');

-- A stale admin session may not execute.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin2'), 3600);
select throws_like(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case2')),
  'reauth_required%', 'a stale administrator session cannot carry out a transfer');
reset role;
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin2'));
select public.admin_execute_recovery((select value::uuid from fx where key = 'case2'));
reset role;

select is((select phone from auth.users where id = (select value::uuid from fx where key = 'owner')), '+919000220002',
  'the original account now signs in with the verified new number');
select is((select id::text from public.provider_profiles where phone_e164 = '+919000220002'), (select value from fx where key = 'p'),
  'the listing is the same row, still owned by the original account');
select is((select status::text || '/' || phone_display_consented::text from public.provider_profiles where id = (select value::uuid from fx where key = 'p')),
  'paused/false', 'it is paused with phone consent reset for the new number');
select is((select count(*)::int from auth.users where id = (select value::uuid from fx where key = 'claimant')), 0,
  'the claimant''s temporary empty account is gone');
select is((select count(*)::int from auth.sessions where user_id = (select value::uuid from fx where key = 'owner')), 0,
  'every old session of the account (including a thief''s) is revoked');
select is((select count(*)::int from private.audit_events
           where action in ('recovery_case_opened', 'recovery_case_approve', 'recovery_case_disputed', 'recovery_executed', 'phone_changed')), 7,
  'every step is audited: 2 opened, 2 approved, 1 disputed, 1 executed, 1 phone change');
select tests.authenticate_as_admin((select value::uuid from fx where key = 'admin2'));
select throws_like(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case2')),
  'conflict%', 'replaying the execution does nothing');
reset role;

select * from finish();
rollback;
