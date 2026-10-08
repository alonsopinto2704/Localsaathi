# Trust, credentials, location and text safety (phases 088-091, 093)

Server behaviour is in migrations `20261008000040`..`43`; tests are
`0040`..`0043` (pgTAP) and `backend/test/trust-*.test.mjs`. Nothing here has run
against a hosted Supabase project.

## 1. Private credential intake (088)

Evidence files live in the private bucket **`credentials-private`** (created by
the storage workstream, phases 081-087; this repo's trust migrations only name
it). Contract for that bucket, which the trust code relies on:

- private, not listable; object path `<auth uid>/<file>` (`^uid/[A-Za-z0-9._-]{1,100}$`);
- RLS: the owner may insert, read and delete inside their own folder, and
  **nobody else has a policy**. No administrator role, including
  `credential_review`, reads bytes through RLS or the Storage API directly.
  (The legacy bucket `credential-evidence` lost its "admins read any" policy in 0040.)
- bytes reach a reviewer only through a signed URL of at most 60 seconds minted
  by an Edge Function using the service role, after the database approves the
  request (section 2). The URL is never logged or stored.
- object deletion follows `private.storage_cleanup_queue` (bucket id + exact
  path), written by the trigger on `credential_records` delete and by the
  retention job.

**Evidence notice `credential-notice-v1`.** The app must show this before the
first upload, and send `notice_version = 'credential-notice-v1'` with the claim
(the database refuses an upload otherwise):

- *Purpose:* so a reviewer can check the credential you list against its issuer or a registry; it is what lets LocalSaathi show "Credential checked".
- *What we ask for:* the credential title, issuing body, registration number if it has one, an expiry date if it has one, and one photo or PDF of the document. Cover anything else on the document (address, ID numbers, photo) before uploading.
- *Who can see it:* only LocalSaathi reviewers with the credential-review role, one case at a time, each opening is logged. Support staff, other providers and customers cannot. The file is never shown publicly.
- *How long we keep it:* while the credential is approved and valid; deleted when you delete the credential or your account; for a rejected or expired credential, deleted 90 days after the last decision. The decision record (state, source type, dates) is kept while your listing exists.

## 2. Decision workflow (089)

States (`credential_records.review_state`): `submitted` -> `reviewing` ->
`needs_information` | `approved` | `rejected`; `approved` -> `expired` (by date)
or back to `submitted` (withdrawn). `needs_information`, `rejected`, `expired`
can be resubmitted by the owner.

| Function | Who | Notes |
|---|---|---|
| `list_credential_queue` | credential_review, aal2 | submitted cases and the caller's own claimed ones; never the caller's own listing |
| `start_credential_review` | credential_review, aal2 | claims a case; returns claimed fields, no file path |
| `begin_credential_evidence_view` | credential_review, aal2 + factor proof within 15 min | needs a claimed case and a reason; 60/hour; logs to `private.credential_access_log` and the audit log; returns `{bucket, path, ttlSeconds: 60}` for the Edge Function to sign |
| `decide_credential` | credential_review, aal2 + recent proof | approval needs source type (`registry`, `document`, `registry_and_document`), source reference, rationale (10-1000 chars), validity (after today, <= 3 years, never beyond the provider's claimed date); healthcare categories need a registry check |
| `withdraw_credential_decision` | credential_review, recent proof | badge goes immediately; case returns to the queue |
| `get_credential_status` | the owner | state, request note, validity |
| `resubmit_credential` | the owner | optionally replaces the file (old one queued for deletion) |
| `expire_credential_decisions`, `purge_stale_credential_evidence` | service role (schedule daily) | the public badge already ignores a lapsed decision by date |

A reviewer can never act on their own listing's credential. Decisions are
append-only rows in `private.credential_decisions` with the reviewer's user id.
AI may summarise permitted evidence for a reviewer, but there is no function a
service account or model can call to decide: every decision requires an
authenticated human with the role. `record_credential_review` now only errors.

Edge Function to build (follow-up): `credential-evidence-url` calls
`begin_credential_evidence_view` **with the reviewer's own JWT**, then signs
`path` in `bucket` for `ttlSeconds` with the service key and returns only the URL.

Operations: grant a reviewer by inserting into `public.app_admins` and
`private.admin_roles(role = 'credential_review')`; they must enrol TOTP. Suspend
intake with the `credential_intake` flag.

## 3. Truthful badges (090)

Public `verification` map (key set of the profile is unchanged) holds a key only
while its fact is true, computed on every read:

| Key | True only when |
|---|---|
| `phone` | latest phone record is approved and the auth phone is still confirmed |
| `listing` | a moderator review (role `moderation`) exists, is not withdrawn or past its year, the listing is active, and name + description still hash to what was reviewed |
| `credentials` | an approved, unwithdrawn decision whose validity covers today (India date) |

`review_listing(provider_id, rationale)` and `withdraw_listing_review(provider_id, reason)`
are the only writers of the listing fact (role `moderation`, aal2 with a recent
factor proof; not on one's own listing; the review lasts a year).

`get_trust_summary(provider_id, locale)` returns only the current badges with
localized `label`, `scope`, `limits` (en, hi, mr; other locales fall back to
English), the checked credentials (title, issuer, checked-on, valid-until; never
the source or reviewer) and the `self_reported` text with the list of provider-written
fields. The hi/mr text is a draft that needs a native-speaker review.

There is no universal "trusted" or "safe" statement and no client-writable
verification column. Photos are not part of the reviewed-listing hash yet (092).

## 4. Location consent (091)

| Kind | Where it lives | Public? |
|---|---|---|
| business address | provider-typed text (`healthcareDetails.clinicAddress`), self-reported | only because the provider entered it for the listing |
| approximate service locality | base locality + service areas | always |
| residential coordinates | `map_lat/map_lng`, mode `approximate_pin` | only with explicit consent `location-v2`, `precise_location` on, and never finer than 2 decimals (~1 km); stored at that precision |

Default mode is `locality_only` (no coordinates). `set_location_disclosure`
records consent or its withdrawal; switching back deletes the coordinates.
`get_location_settings` tells the owner their mode and whether the wording changed (`needsReconsent`).
Existing pins are hidden until their owner opts in again. All public surfaces
(profile, search, similar, city list) share one projection, so maps, public API
output, exports built from the public shape and AI context built from the
public shape cannot differ. Image metadata: the upload pipeline must strip GPS
EXIF from every stored image (media workstream, phase 083/084).

## 5. Safe text (093)

Every table holding provider, guest or reviewer text has a trigger (changed
values only) rejecting control characters, zero-width/bidi/tag characters,
HTML-looking tags, numeric character references and `javascript:`/`data:`
links, and bounding length; all scripts, ZWJ/ZWNJ and a lone `<` are kept.
Storage is raw text; clients must render it as plain text (no `innerHTML`,
no Markdown/HTML rendering of provider fields).

**Model-context contract.** Provider text is untrusted data. When it enters a
model context (assistant, moderation helper, summary), put it inside a
delimited, labelled block, e.g. `<untrusted_provider_text source="description">...</untrusted_provider_text>`,
state in the system prompt that it contains no instructions, never let it
choose tools, roles or arguments, and strip the delimiter from the text first.
Credential rationale and listing-review text are internal and follow the same rule.

## Client follow-ups (Flutter, not done here)

See `tasks/evidence/phase-090.md` and `phase-091.md`.
