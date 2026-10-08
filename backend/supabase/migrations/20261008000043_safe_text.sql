-- 0043: phase 093, safe profile and caption text.
--
-- Before: user text was only length-checked, inside individual RPCs. A listing
-- name, description, caption or report could carry HTML, script-scheme links,
-- bidi overrides, zero-width characters or invisible Unicode "tag" characters
-- (used to hide instructions from people but not from language models), and a
-- new write path (the media workstream adds some) would have had to remember
-- to re-check.
--
-- After: one rule, enforced by a trigger on every table that stores
-- provider-, guest- or reviewer-written text, so no RPC, import or future write
-- path can skip it. The rule rejects (never silently rewrites) what is
-- dangerous or deceptive and keeps everything else, including every script:
--   rejected: control characters except tab/CR/LF, C1 controls; zero-width
--             space, bidi marks and overrides, line/paragraph separators,
--             word joiner and invisible operators, BOM, interlinear
--             annotation marks, Unicode tag characters (U+E0000..E007F);
--             an HTML-looking tag or comment (< followed by a letter, / ! ?);
--             numeric character references (&#...); javascript:, vbscript: and
--             data:text/... or data:application/... links.
--   kept:     Devanagari, Tamil, Arabic, CJK, emoji, accents; ZWNJ (U+200C) and
--             ZWJ (U+200D), which Indic conjuncts and emoji sequences need; a
--             lone '<' or '>' as in "under 5 < 10 km".
-- Storage is raw text; escaping is the renderer's job. Server JSON is built
-- with jsonb functions, which escape quotes, backslashes and control characters
-- (tested in 0043). Only a changed value is checked, so an old row that
-- predates this rule never blocks an unrelated update.
--
-- Contract for model contexts (docs/trust-and-credentials.md section 5):
-- provider text is untrusted data; it must be passed inside a delimited,
-- labelled block and can never be a source of policy or tool instructions.

create function private.text_problem(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_text ~ '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F\u0080-\u009F]' then 'control character'
    when p_text ~ '[​‎‏  ‪-‮⁠-⁤⁦-⁩﻿￹-￻\U000E0000-\U000E007F]'
      then 'invisible or direction-changing character'
    when p_text ~ '<[A-Za-z/!?]' then 'markup'
    when p_text ~* '&#[0-9x]' then 'character reference'
    when p_text ~* '(javascript|vbscript)\s*:' or p_text ~* 'data\s*:\s*(text|application)/' then 'script link'
  end;
$$;

create function private.assert_safe_text(p_field text, p_text text, p_max int)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_problem text;
begin
  if p_text is null then
    return;
  end if;
  if char_length(p_text) > p_max then
    raise exception 'validation_failed: % is limited to % characters', p_field, p_max;
  end if;
  v_problem := private.text_problem(p_text);
  if v_problem is not null then
    raise exception 'validation_failed: % contains an unsupported %', p_field, v_problem;
  end if;
end;
$$;

-- Trigger arguments are 'column:max' pairs.
create function private.check_user_text()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new jsonb := to_jsonb(new);
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) end;
  v_arg text;
  v_col text;
begin
  foreach v_arg in array tg_argv loop
    v_col := split_part(v_arg, ':', 1);
    continue when v_old is not null and v_new -> v_col is not distinct from v_old -> v_col;
    perform private.assert_safe_text(v_col, v_new ->> v_col, split_part(v_arg, ':', 2)::int);
  end loop;
  return new;
end;
$$;

create trigger trg_safe_text before insert or update on public.provider_profiles
  for each row execute function private.check_user_text('display_name:80', 'description:1000', 'languages:600');
create trigger trg_safe_text before insert or update on public.provider_photos
  for each row execute function private.check_user_text('caption:140');
create trigger trg_safe_text before insert or update on public.provider_starting_prices
  for each row execute function private.check_user_text('note:140');
create trigger trg_safe_text before insert or update on public.provider_healthcare_details
  for each row execute function private.check_user_text('qualification:300', 'specialty:300', 'clinic_name:300',
    'clinic_address:300', 'consultation_hours_note:300', 'registration_number:300', 'registration_council:300');
create trigger trg_safe_text before insert or update on public.credential_records
  for each row execute function private.check_user_text('title:200', 'issuing_body:200', 'registration_number:60', 'note_to_provider:500');
create trigger trg_safe_text before insert or update on public.reports
  for each row execute function private.check_user_text('details:1000');
create trigger trg_safe_text before insert or update on private.credential_decisions
  for each row execute function private.check_user_text('rationale:1000', 'source_reference:300');
create trigger trg_safe_text before insert or update on private.listing_reviews
  for each row execute function private.check_user_text('rationale:1000');

revoke execute on function private.text_problem(text), private.assert_safe_text(text, text, int),
  private.check_user_text() from public, anon, authenticated;
