-- 0041: phase 090, truthful trust badges.
--
-- Before: the public 'verification' map was "latest verification_records row per
-- kind, if approved". Nothing expired it, a withdrawn or lapsed credential kept
-- its badge until someone wrote another row, there was no reviewed-listing
-- fact at all, and no server-side statement of what a badge does and does not
-- mean.
--
-- After, every public badge is computed on read from evidence that still holds:
--   phone    latest phone record approved AND the auth phone is still confirmed
--   listing  an unwithdrawn, unexpired moderator review whose content hash
--            (display name + description) still matches, on an active listing
--   credentials  an approved, unwithdrawn, in-validity decision (0040)
-- so expiry, withdrawal, suspension and edits after review all remove the badge
-- from search, profile, similar-provider and city lists in the same request.
-- Everything else a provider writes is "self-reported" and says so. Nothing a
-- client sends can create a badge: there is no writable verification column,
-- and update_profile_full ignores unknown keys (tested in 0041).
--
-- The public key set is unchanged (the Flutter parser and 0007 depend on it):
-- 'verification' keeps its shape {phone|credentials|listing: 'approved'} but is
-- now present only while true. Richer, localized text comes from
-- get_trust_summary().

-- ---------------------------------------------------------------------------
-- Localized scope and limitation text. en is authoritative; hi/mr are drafts
-- that need a native-speaker review before launch (tasks/evidence/phase-090.md).
create table public.trust_copy (
  key text not null check (key in ('phone_verified', 'listing_reviewed', 'credential_checked', 'self_reported')),
  locale text not null check (locale in ('en', 'hi', 'mr')),
  label text not null,
  scope text not null,
  limits text not null,
  primary key (key, locale)
);
alter table public.trust_copy enable row level security;
revoke all on public.trust_copy from public, anon, authenticated;
grant select on public.trust_copy to anon, authenticated;
create policy "trust copy is public" on public.trust_copy for select using (true);

insert into public.trust_copy (key, locale, label, scope, limits) values
  ('phone_verified', 'en', 'Phone verified',
   'This person entered a one-time code sent to this number, so they control it.',
   'This is not an identity, background or qualification check.'),
  ('listing_reviewed', 'en', 'Listing reviewed',
   'A LocalSaathi reviewer read this listing''s name and description for misleading or unsuitable content. If the provider edits them, the label is removed until it is reviewed again.',
   'It does not check the quality or safety of the work, or any claim not marked as checked.'),
  ('credential_checked', 'en', 'Credential checked',
   'A reviewer compared the credential shown with a document or registry entry, and it is within its checked period.',
   'It covers only that credential and period. It is not a guarantee of service quality or of a person''s safety.'),
  ('self_reported', 'en', 'Provided by the provider',
   'The description, languages, prices, hours and professional details are written by the provider.',
   'LocalSaathi has not checked them unless a badge above says so.'),
  ('phone_verified', 'hi', 'फ़ोन सत्यापित',
   'इस व्यक्ति ने इस नंबर पर भेजा गया एक-बार का कोड दर्ज किया, यानी नंबर इनके नियंत्रण में है।',
   'यह पहचान, पृष्ठभूमि या योग्यता की जाँच नहीं है।'),
  ('listing_reviewed', 'hi', 'लिस्टिंग की समीक्षा हुई',
   'LocalSaathi के समीक्षक ने इस लिस्टिंग का नाम और विवरण भ्रामक या अनुचित सामग्री के लिए पढ़ा। प्रदाता इन्हें बदलता है तो समीक्षा दोबारा होने तक यह लेबल हट जाता है।',
   'इससे काम की गुणवत्ता या सुरक्षा की जाँच नहीं होती, और जिन दावों पर ''जाँचा गया'' नहीं लिखा, उनकी भी नहीं।'),
  ('credential_checked', 'hi', 'प्रमाण-पत्र की जाँच हुई',
   'समीक्षक ने दिखाए गए प्रमाण-पत्र को किसी दस्तावेज़ या रजिस्ट्री की प्रविष्टि से मिलाया, और वह जाँची गई अवधि के भीतर है।',
   'यह केवल उसी प्रमाण-पत्र और अवधि पर लागू है। यह सेवा की गुणवत्ता या व्यक्ति की सुरक्षा की गारंटी नहीं है।'),
  ('self_reported', 'hi', 'प्रदाता द्वारा दी गई जानकारी',
   'विवरण, भाषाएँ, कीमतें, समय और व्यावसायिक जानकारी प्रदाता ने स्वयं लिखी है।',
   'ऊपर कोई लेबल न कहे तो LocalSaathi ने इसकी जाँच नहीं की है।'),
  ('phone_verified', 'mr', 'फोन सत्यापित',
   'या व्यक्तीने या नंबरवर पाठवलेला एकवेळचा कोड टाकला, म्हणजे नंबर त्यांच्या ताब्यात आहे.',
   'ही ओळख, पार्श्वभूमी किंवा पात्रतेची तपासणी नाही.'),
  ('listing_reviewed', 'mr', 'लिस्टिंगचे पुनरावलोकन झाले',
   'LocalSaathi च्या पुनरावलोकनकर्त्याने या लिस्टिंगचे नाव आणि वर्णन दिशाभूल करणारा किंवा अयोग्य मजकूर आहे का ते वाचले. सेवा देणाऱ्याने ते बदलले तर पुन्हा पुनरावलोकन होईपर्यंत हे लेबल काढले जाते.',
   'यातून कामाचा दर्जा किंवा सुरक्षितता तपासली जात नाही, तसेच ''तपासले'' असे न लिहिलेले दावेही तपासले जात नाहीत.'),
  ('credential_checked', 'mr', 'प्रमाणपत्राची तपासणी झाली',
   'पुनरावलोकनकर्त्याने दाखवलेले प्रमाणपत्र एखाद्या कागदपत्राशी किंवा नोंदणीतील नोंदीशी जुळवले आणि ते तपासलेल्या कालावधीत आहे.',
   'हे फक्त त्या प्रमाणपत्रासाठी आणि कालावधीसाठी लागू आहे. सेवेचा दर्जा किंवा व्यक्ती सुरक्षित असल्याची ही हमी नाही.'),
  ('self_reported', 'mr', 'सेवा देणाऱ्याने दिलेली माहिती',
   'वर्णन, भाषा, किमती, वेळा आणि व्यावसायिक माहिती सेवा देणाऱ्याने स्वतः लिहिली आहे.',
   'वरील एखाद्या लेबलमध्ये सांगितल्याशिवाय LocalSaathi ने याची तपासणी केलेली नाही.');

-- ---------------------------------------------------------------------------
-- Listing review (the only source of the 'listing reviewed' fact).
create table private.listing_reviews (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id),
  rationale text not null check (char_length(btrim(rationale)) between 10 and 1000),
  content_hash text not null,
  reviewed_at timestamptz not null default now(),
  valid_until date not null,
  withdrawn_at timestamptz,
  withdrawn_by uuid references auth.users(id),
  withdraw_reason text check (char_length(withdraw_reason) between 5 and 300)
);
create index listing_reviews_provider on private.listing_reviews (provider_id, reviewed_at desc);
revoke all on private.listing_reviews from public, anon, authenticated;

-- ponytail: name + description only. Photos join the hash when the portfolio
-- moderation pipeline (092) gives them a reviewed state.
create function private.listing_content_hash(p_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select md5(pp.display_name || chr(31) || coalesce(pp.description, '')) from public.provider_profiles pp where pp.id = p_id;
$$;

create function public.review_listing(p_provider_id uuid, p_rationale text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pp public.provider_profiles;
  v_id uuid;
begin
  perform private.require_admin_role('moderation', true);
  if char_length(btrim(coalesce(p_rationale, ''))) not between 10 and 1000 then
    raise exception 'validation_failed: a rationale (10-1000 characters) is required';
  end if;
  select * into v_pp from public.provider_profiles where id = p_provider_id for update;
  if not found then
    raise exception 'not_found: listing not found';
  end if;
  if v_pp.user_id = auth.uid() then
    raise exception 'not_owner: you cannot review your own listing';
  end if;
  if v_pp.status <> 'published' or v_pp.moderation_status <> 'active' then
    raise exception 'conflict: only a published, active listing can be marked reviewed';
  end if;
  insert into private.listing_reviews (provider_id, reviewer_id, rationale, content_hash, valid_until)
  values (v_pp.id, auth.uid(), btrim(p_rationale), private.listing_content_hash(v_pp.id),
          (now() at time zone 'Asia/Kolkata')::date + 365)
  returning id into v_id;
  perform private.write_audit('listing_reviewed', 'provider_profile', v_pp.id::text, null,
    jsonb_build_object('review_id', v_id));
  return jsonb_build_object('reviewId', v_id);
end;
$$;

create function public.withdraw_listing_review(p_provider_id uuid, p_reason text)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n int;
begin
  perform private.require_admin_role('moderation', true);
  if char_length(btrim(coalesce(p_reason, ''))) not between 5 and 300 then
    raise exception 'validation_failed: a reason (5-300 characters) is required';
  end if;
  update private.listing_reviews set withdrawn_at = now(), withdrawn_by = auth.uid(), withdraw_reason = btrim(p_reason)
    where provider_id = p_provider_id and withdrawn_at is null;
  get diagnostics v_n = row_count;
  perform private.write_audit('listing_review_withdrawn', 'provider_profile', p_provider_id::text, null,
    jsonb_build_object('count', v_n));
  return v_n;
end;
$$;

-- ---------------------------------------------------------------------------
-- The one place badge truth is decided.
create function private.trust_state(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'phone', coalesce((select v.status = 'approved' from public.verification_records v
                       where v.provider_id = pp.id and v.kind = 'phone'
                       order by v.created_at desc limit 1), false)
             and exists (select 1 from auth.users u where u.id = pp.user_id and u.phone_confirmed_at is not null),
    'listing', pp.moderation_status = 'active' and exists (
                 select 1 from private.listing_reviews r
                 where r.provider_id = pp.id and r.withdrawn_at is null
                   and r.valid_until >= (now() at time zone 'Asia/Kolkata')::date
                   and r.content_hash = private.listing_content_hash(pp.id)),
    'credentials', exists (
                 select 1 from public.credential_records cr
                 join private.credential_decisions d on d.id = cr.current_decision_id
                 where cr.provider_id = pp.id and cr.review_state = 'approved'
                   and d.decision = 'approved' and d.withdrawn_at is null
                   and (now() at time zone 'Asia/Kolkata')::date between d.valid_from and d.valid_until))
  from public.provider_profiles pp where pp.id = p_id;
$$;

create function private.trust_overlay(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('verification', jsonb_strip_nulls(jsonb_build_object(
    'phone', case when t.s @> '{"phone": true}' then 'approved' end,
    'listing', case when t.s @> '{"listing": true}' then 'approved' end,
    'credentials', case when t.s @> '{"credentials": true}' then 'approved' end)))
  from (select private.trust_state(p_id) as s) t;
$$;

-- Wrap rather than copy the projection: whatever other phases put in
-- public_profile_json (photos, healthcare, location) stays theirs; only the
-- 'verification' value is replaced.
alter function public.public_profile_json(uuid) rename to public_profile_json_base;
alter function public.public_profile_json_base(uuid) set schema private;
create function public.public_profile_json(p_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select private.public_profile_json_base(p_id) || private.trust_overlay(p_id);
$$;
revoke execute on function public.public_profile_json(uuid) from public, anon, authenticated;

-- Detail for the badge explainer: only what is currently true, with scope and
-- limits in the requested language (falls back to English), plus which public
-- fields are provider-written.
create function public.get_trust_summary(p_provider_id uuid, p_locale text default 'en')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_loc text := case when lower(left(coalesce(p_locale, ''), 2)) in ('hi', 'mr') then lower(left(p_locale, 2)) else 'en' end;
  v_state jsonb;
begin
  if not public.is_publicly_listed(p_provider_id) then
    return null;
  end if;
  v_state := private.trust_state(p_provider_id);
  return jsonb_build_object(
    'locale', v_loc,
    'badges', coalesce((
      select jsonb_agg(jsonb_build_object('key', c.key, 'label', c.label, 'scope', c.scope, 'limits', c.limits)
                       order by array_position(array['phone_verified', 'listing_reviewed', 'credential_checked'], c.key))
      from public.trust_copy c
      where c.locale = v_loc and c.key in ('phone_verified', 'listing_reviewed', 'credential_checked')
        and (v_state ->> case c.key when 'phone_verified' then 'phone' when 'listing_reviewed' then 'listing' else 'credentials' end)::boolean
    ), '[]'::jsonb),
    'checkedCredentials', coalesce((
      select jsonb_agg(jsonb_build_object('title', cr.title, 'issuingBody', cr.issuing_body,
                                          'checkedOn', d.created_at::date, 'validUntil', d.valid_until) order by cr.title)
      from public.credential_records cr
      join private.credential_decisions d on d.id = cr.current_decision_id
      where cr.provider_id = p_provider_id and cr.review_state = 'approved' and d.decision = 'approved'
        and d.withdrawn_at is null and (now() at time zone 'Asia/Kolkata')::date between d.valid_from and d.valid_until
    ), '[]'::jsonb),
    'selfReported', (select jsonb_build_object('key', c.key, 'label', c.label, 'scope', c.scope, 'limits', c.limits)
                     from public.trust_copy c where c.locale = v_loc and c.key = 'self_reported'),
    'selfReportedFields', jsonb_build_array('description', 'languages', 'startingPrices', 'workingHours',
                                            'healthcareDetails', 'photos')
  );
end;
$$;

revoke execute on function
  public.review_listing(uuid, text), public.withdraw_listing_review(uuid, text),
  public.get_trust_summary(uuid, text), private.trust_state(uuid), private.trust_overlay(uuid),
  private.listing_content_hash(uuid)
  from public, anon, authenticated;
grant execute on function public.review_listing(uuid, text), public.withdraw_listing_review(uuid, text) to authenticated;
grant execute on function public.get_trust_summary(uuid, text) to anon, authenticated;
