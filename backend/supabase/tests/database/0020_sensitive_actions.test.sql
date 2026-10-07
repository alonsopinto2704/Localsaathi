-- Phase 055 (migration 0026): recent authentication for sensitive actions.
-- Phones +91900020xxxx.
begin;
select plan(15);

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
grant all on fx to service_role;
insert into fx values
  ('a', tests.create_phone_user('+919000200001')::text),
  ('b', tests.create_phone_user('+919000200002')::text);

-- request_sensitive_action: needs a factor proof in the last 5 minutes.
select tests.authenticate_with_amr((select value::uuid from fx where key = 'a'), 30);
select is((public.request_sensitive_action('delete_account')->>'ok')::boolean, true,
  'a session whose last code was 30 s ago can request the grant');
select tests.authenticate_with_amr((select value::uuid from fx where key = 'a'), 900);
select throws_like($$ select public.request_sensitive_action('delete_account') $$, 'reauth_required%',
  'a valid but old session (15 min since the last code) is refused');
select tests.authenticate_with_amr((select value::uuid from fx where key = 'a'), -3600);
select throws_like($$ select public.request_sensitive_action('delete_account') $$, 'reauth_required%',
  'a factor proof dated in the future is not accepted');
-- A token with no amr at all (e.g. issued before factors were stamped).
select set_config('request.jwt.claims', json_build_object('sub', (select value from fx where key = 'a'), 'role', 'authenticated')::text, true);
select throws_like($$ select public.request_sensitive_action('delete_account') $$, 'reauth_required%',
  'a token with no amr claim is treated as stale');
select tests.authenticate_with_amr((select value::uuid from fx where key = 'a'), 30);
select throws_like($$ select public.request_sensitive_action('transfer_listing') $$, 'validation_failed%',
  'unknown actions are rejected');
reset role;

select tests.authenticate_as_anon();
select throws_ok($$ select public.request_sensitive_action('delete_account') $$, '42501', null,
  'anon cannot request a grant');
reset role;

-- The phone-change trigger needs a live grant, and consumes it.
select throws_like(
  format($sql$ update auth.users set phone_change = '+919000200009', phone_change_sent_at = now() where id = %L $sql$,
    (select value from fx where key = 'b')),
  'reauth_required%', 'GoTrue cannot start a phone change for a user with no grant');
select tests.authenticate_with_amr((select value::uuid from fx where key = 'b'), 20);
select public.request_sensitive_action('phone_change');
reset role;
select lives_ok(
  format($sql$ update auth.users set phone_change = '+919000200009', phone_change_sent_at = now() where id = %L $sql$,
    (select value from fx where key = 'b')),
  'with a fresh grant the change can start');
select throws_like(
  format($sql$ update auth.users set phone_change_sent_at = now() + interval '1 minute' where id = %L $sql$,
    (select value from fx where key = 'b')),
  'reauth_required%', 'the grant is single use: re-sending the code needs a new confirmation');
select throws_like(
  format($sql$ update auth.users set phone_change = '+919000200008', phone_change_sent_at = now() + interval '2 minutes' where id = %L $sql$,
    (select value from fx where key = 'a')),
  'reauth_required%', 'one user''s grant never serves another user');

-- Expired grants do not count.
insert into private.sensitive_grants (user_id, action, expires_at)
  values ((select value::uuid from fx where key = 'a'), 'phone_change', now() - interval '1 minute');
select throws_like(
  format($sql$ update auth.users set phone_change = '+919000200008', phone_change_sent_at = now() + interval '3 minutes' where id = %L $sql$,
    (select value from fx where key = 'a')),
  'reauth_required%', 'an expired grant is refused');

-- delete_account grants are consumed by the Edge Function with the service role.
select tests.authenticate_with_amr((select value::uuid from fx where key = 'a'), 30);
select public.request_sensitive_action('delete_account');
reset role;
select tests.authenticate_as((select value::uuid from fx where key = 'a'));
select throws_ok(
  format($sql$ select public.consume_sensitive_grant(%L::uuid, 'delete_account') $sql$, (select value from fx where key = 'a')),
  '42501', null, 'a signed-in user cannot consume their own grant (only the service role can)');
reset role;
set local role service_role;
select is(public.consume_sensitive_grant((select value::uuid from fx where key = 'a'), 'delete_account'), true,
  'the service role consumes the live grant once');
select is(public.consume_sensitive_grant((select value::uuid from fx where key = 'a'), 'delete_account'), false,
  'a second consume finds nothing (retry-safe: no double use)');
reset role;

-- Abuse bound: at most 10 grants an hour.
select tests.authenticate_with_amr((select value::uuid from fx where key = 'b'), 10);
select count(public.request_sensitive_action('export_private_evidence')) from generate_series(1, 9);
select throws_like($$ select public.request_sensitive_action('export_private_evidence') $$, 'rate_limited%',
  'grant requests are rate limited');
reset role;

select * from finish();
rollback;
