-- Regressions for the /code-review findings on migrations 0014-0018.
-- Phone range +91900000140x.
begin;
select plan(9);
select tests.ensure_reference_data();

create temporary table fx (key text primary key, value text);
select tests.share_fixture('fx');
insert into fx values ('owner', tests.create_phone_user('+919000001401')::text);
insert into fx select 'a', tests.create_published_provider(
  (select value::uuid from fx where key = 'owner'), '+919000001401', 'Review Fix Listing')::text;

-- 1. Audit redaction ignores UUIDs whose last segment is all digits.
select lives_ok(
  $sql$ select private.write_audit('test_action', 'provider_profile', 'x', null,
          jsonb_build_object('provider_id', '0a1b2c3d-1111-4222-8333-123456789012')) $sql$,
  'a UUID with a 12-digit final segment is not mistaken for a phone number');
select throws_like(
  $sql$ select private.write_audit('test_action', 'x', 'x', 'call 9876543210 back') $sql$,
  '%audit_redaction%', 'a phone-like number in the reason is still refused');

-- 2. The client-controlled (leftmost) X-Forwarded-For entry does not change
-- the source: two reports with different spoofed left entries but the same
-- edge-appended right entry dedupe to one receipt.
select tests.authenticate_as_anon();
select set_config('request.headers', '{"x-forwarded-for":"1.1.1.1, 198.51.100.20"}', true);
insert into fx select 'r1', public.submit_report((select value::uuid from fx where key = 'a'), 'other')->>'receiptId';
select set_config('request.headers', '{"x-forwarded-for":"2.2.2.2, 198.51.100.20"}', true);
insert into fx select 'r2', public.submit_report((select value::uuid from fx where key = 'a'), 'other')->>'receiptId';
reset role;
select is((select value from fx where key = 'r2'), (select value from fx where key = 'r1'),
  'spoofing the leftmost X-Forwarded-For entry does not create a new reporter');

-- 3. Without any client signal, distinct guests are not merged into one
-- receipt and do not share a lockout bucket.
select tests.authenticate_as_anon();
select set_config('request.headers', '{}', true);
insert into fx select 'n' || g, public.submit_report((select value::uuid from fx where key = 'a'), 'other')->>'receiptId'
  from generate_series(1, 6) g;
reset role;
select is((select count(distinct value)::int from fx where key like 'n%'), 6,
  'with no source signal, six guest reports are six reports (no dedupe, no shared 5/hour lockout)');

-- 4. Null boolean filters behave like false instead of hiding everything.
select tests.authenticate_as_anon();
select ok(
  (public.search_providers('test-active-city', 'test-locality-a', '', '{}', '{}', null, null)->>'totalCount')::int >= 1,
  'null open-now / home-visit filters do not filter out every listing');
reset role;

-- 5. A working-hours day without a weekday is a validation error, not a raw
-- not-null violation.
insert into fx values ('reg', tests.create_phone_user('+919000001402')::text);
select tests.authenticate_as((select value::uuid from fx where key = 'reg'));
select throws_like(
  $sql$ select public.register_profile('{"displayName":"X","baseCityId":"test-active-city","baseLocalityId":"test-locality-a",
        "categoryIds":["test-category-plumbing"],"serviceAreaIds":["test-locality-a"],
        "workingHours":{"days":[{"open":540,"close":1080}]}}'::jsonb) $sql$,
  '%validation_failed%', 'a day without a weekday is rejected as validation_failed');
reset role;

-- 6. search_providers uses the single eligibility predicate: un-approving the
-- only category hides the listing from search as from every other path.
update public.service_categories set is_approved_for_launch = false where id = 'test-category-plumbing';
select tests.authenticate_as_anon();
select is(
  (public.search_providers('test-active-city', 'test-locality-a')->>'totalCount')::int, 0,
  'search honours is_publicly_listed (category no longer approved)');
select is(public.get_public_profile((select value::uuid from fx where key = 'a')), null,
  'and so does get_public_profile');
reset role;
update public.service_categories set is_approved_for_launch = true where id = 'test-category-plumbing';
select tests.authenticate_as_anon();
select ok(
  (public.search_providers('test-active-city', 'test-locality-a')->>'totalCount')::int >= 1,
  're-approving the category brings it back');
reset role;

select * from finish();
rollback;
