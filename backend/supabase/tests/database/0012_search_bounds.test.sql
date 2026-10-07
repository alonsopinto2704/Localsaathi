-- Phases 031/034: bounded public search, literal wildcards, open-now rule.
-- Phone range +9190000012xx.
begin;
select plan(21);
select tests.ensure_reference_data();

-- 52 listings: one with LIKE metacharacters in its name, one that a wildcard
-- reading of that name would also match, the rest plain.
do $$
declare
  i int;
begin
  for i in 1..52 loop
    perform tests.create_published_provider(
      tests.create_phone_user('+9190000012' || lpad(i::text, 2, '0')),
      '+9190000012' || lpad(i::text, 2, '0'),
      case i when 1 then 'A_B%C' when 2 then 'AxByzC' else 'Bulk ' || i end);
  end loop;
end $$;

select tests.authenticate_as_anon();
select throws_like(
  format($sql$ select public.search_providers('test-active-city', 'test-locality-a', %L) $sql$, repeat('x', 81)),
  '%validation_failed:%', 'search text of 81 characters is rejected');
select throws_like(
  $sql$ select public.search_providers('test-active-city', 'test-locality-a', '', array_fill('test-category-plumbing'::text, array[21])) $sql$,
  '%validation_failed:%', '21 category filters are rejected');
select throws_like(
  $sql$ select public.search_providers('test-active-city', 'test-locality-a', p_offset => 501) $sql$,
  '%validation_failed:%', 'an offset of 501 is rejected');
select is(
  jsonb_array_length(public.search_providers('test-active-city', 'test-locality-a', p_limit => 100000)->'items'),
  50, 'a huge p_limit is capped at 50 items');
select is(
  (public.search_providers('test-active-city', 'test-locality-a', 'A_B%C')->>'totalCount')::int,
  1, 'the text A_B%C matches only the listing literally named so');
select is(
  public.search_providers('test-active-city', 'test-locality-a', 'A_B%C')->'items'->0->'provider'->>'displayName',
  'A_B%C', 'and that listing is the one found');
select is(
  (public.search_providers('test-active-city', 'test-locality-a', '%')->>'totalCount')::int,
  1, 'a lone % is a literal, not a match-everything wildcard');
select is(
  (public.search_providers('test-active-city', 'test-locality-a', '_')->>'totalCount')::int,
  1, 'a lone _ is a literal, not a single-character wildcard');
reset role;

-- private.hours_open(today_open, today_close, yesterday_open, yesterday_close, minutes)
-- Every case of docs/contracts/fixtures/working-hours.json.
select is(private.hours_open(1320, 120, null, null, 60), false, 'overnight window does not cover the same day''s early morning');
select is(private.hours_open(1320, 120, null, null, 1380), true, 'overnight window open late on its own day');
select is(private.hours_open(null, null, 1320, 120, 90), true, 'overnight window spills into the next morning');
select is(private.hours_open(null, null, 1320, 120, 120), false, 'spill closes at the close minute');
select is(private.hours_open(null, null, 1320, 120, 60), true, 'Sunday overnight spills into Monday (week boundary)');
select is(private.hours_open(0, 1439, null, null, 1439), true, 'all-day window includes 23:59');
select is(private.hours_open(0, 1439, null, null, 0), true, 'all-day window includes 00:00');
select is(private.hours_open(540, 1080, null, null, 1080), false, 'day window is closed at its close minute');
select is(private.hours_open(540, 1080, null, null, 539), false, 'day window is closed before opening');
select is(private.hours_open(540, 1080, null, null, 540), true, 'day window open at its open minute');
select is(private.hours_open(null, null, 600, 600, 599), true, 'open == close is a 24-hour window starting at open');
select is(private.hours_open(null, null, 600, 600, 600), false, '24-hour window ends at the next day''s open minute');
select is(private.hours_open(null, null, 540, 1080, 600), false, 'closed today, open yesterday daytime only');

select * from finish();
rollback;
