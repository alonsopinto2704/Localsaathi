-- 0035: phase 086, image derivatives and byte budgets (policy exposure).
--
-- The derivative set is deliberately two: `thumb` (<= 320 px, <= 40 KB) for
-- cards and `full` (<= 1280 px, <= 300 KB) for the detail view; the numbers are
-- the rows of private.media_derivatives (0030) and are enforced at approval
-- (0033). This function hands the SAME numbers to the Edge Function so the
-- encoder and the database cannot disagree.
--
-- Browsing budget: a results page of 20 cards loads thumbs only, so its media
-- ceiling is 20 x thumb.max_bytes = 800 KB (tested against the table). Original
-- resolution is never referenced by a card. URLs are versioned by construction:
-- keys embed the upload id, so a replacement is a new URL and the old revision
-- is never overwritten. Low-quality placeholders (dominant colour / blur hash)
-- are NOT implemented: they need decoded pixels and a client decision.

create function public.media_policy()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'derivatives', (select jsonb_agg(jsonb_build_object('kind', kind, 'maxEdge', max_edge, 'maxBytes', max_bytes, 'quality', quality) order by kind desc)
                    from private.media_derivatives),
    'original', (select jsonb_build_object('maxBytes', max_bytes, 'mime', allowed_mime)
                 from private.media_classes where class = 'portfolio_original'),
    'maxPhotos', private.media_setting('max_photos'),
    'cardPageSize', 20);
$$;

revoke execute on function public.media_policy() from public, anon, authenticated;
grant execute on function public.media_policy() to service_role;
