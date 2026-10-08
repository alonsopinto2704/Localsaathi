-- Audit follow-up (migration 0051): recovery two-person rule and per-claimant
-- rate limit. Phones +91900051xxxx.
begin;
select plan(9);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values
  ('owner', tests.create_phone_user('+919000510001')::text),
  ('t1', tests.create_phone_user('+919000510002')::text),   -- throwaway accounts
  ('t2', tests.create_phone_user('+919000510003')::text),
  ('t3', tests.create_phone_user('+919000510004')::text),
  ('real', tests.create_phone_user('+919000510005')::text), -- the genuine claimant
  ('a1', tests.create_admin('+919000510006')::text),
  ('a2', tests.create_admin('+919000510007')::text);
insert into fx select 'p', tests.create_published_provider((select value::uuid from fx where key = 'owner'), '+919000510001', 'Flooded Listing')::text;
grant all on fx to authenticated;

-- Throwaway accounts file two cases each (six total, past the old per-listing cap of five).
create function pg_temp.file_case(p_user text, p_provider text) returns text language plpgsql as $$
begin
  perform tests.authenticate_as(p_user::uuid);
  return public.open_recovery_case(p_provider::uuid, 'I operate this business from the Andheri shop, lost my SIM')->>'caseId';
end;
$$;
grant execute on function pg_temp.file_case(text, text) to authenticated;
select pg_temp.file_case(value, (select value from fx where key = 'p')) from fx where key in ('t1', 't2', 't3');
reset role;
select pg_temp.file_case(value, (select value from fx where key = 'p')) from fx where key in ('t1', 't2', 't3');
reset role;

select tests.authenticate_as((select value::uuid from fx where key = 't1'));
select throws_like(
  format($sql$ select public.open_recovery_case(%L::uuid, 'I operate this business from the Andheri shop, lost my SIM') $sql$, (select value from fx where key = 'p')),
  'rate_limited%', 'one claimant cannot keep filing against the same listing');
reset role;

select is((select count(*)::int from private.audit_events where action = 'recovery_listing_flood'), 1,
  'the flood raises exactly one audit alert instead of blocking');

select tests.authenticate_as((select value::uuid from fx where key = 'real'));
insert into fx select 'case', public.open_recovery_case((select value::uuid from fx where key = 'p'),
  'I operate this business from the Andheri shop, lost my SIM, new number is mine')->>'caseId';
reset role;
select is((select count(*)::int from private.recovery_cases where claimant_user_id = (select value::uuid from fx where key = 'real')), 1,
  'a genuine claimant can still open a case on a listing others have flooded');

-- Two-person rule.
select tests.authenticate_as_admin((select value::uuid from fx where key = 'a1'));
select public.admin_review_recovery_case((select value::uuid from fx where key = 'case'), 'approve',
  'Called the landline on an old invoice; the owner confirmed the SIM was lost.');
reset role;
update private.recovery_cases set eligible_at = now() - interval '1 minute' where id = (select value::uuid from fx where key = 'case');

select tests.authenticate_as_admin((select value::uuid from fx where key = 'a1'));
select throws_like(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case')),
  'not_owner%', 'the approving reviewer cannot also carry the recovery out');
reset role;
select is((select status from private.recovery_cases where id = (select value::uuid from fx where key = 'case')), 'approved',
  'and the case is untouched');
select tests.authenticate_as_admin((select value::uuid from fx where key = 'a2'));
select lives_ok(
  format($sql$ select public.admin_execute_recovery(%L::uuid) $sql$, (select value from fx where key = 'case')),
  'a different support administrator can execute it');
reset role;
select is((select status from private.recovery_cases where id = (select value::uuid from fx where key = 'case')), 'executed', 'and it is executed');
select is((select details->>'reviewed_by' from private.audit_events where action = 'recovery_executed' order by id desc limit 1),
  (select value from fx where key = 'a1'), 'the audit row names the approving reviewer');
select is((select phone from auth.users where id = (select value::uuid from fx where key = 'owner')), '+919000510005',
  'the owner account now signs in with the genuine claimant''s number');

select * from finish();
rollback;
