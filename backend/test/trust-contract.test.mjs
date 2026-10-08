// Phases 088-093: constants and function names that the migrations, the docs
// and the Edge Functions/Flutter app must agree on cannot drift silently.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const mig = (n) => readFileSync(new URL(`../supabase/migrations/${n}`, import.meta.url), 'utf8');
const m40 = mig('20261008000040_credential_workflow.sql');
const m41 = mig('20261008000041_truthful_trust_badges.sql');
const m42 = mig('20261008000042_location_consent.sql');
const m43 = mig('20261008000043_safe_text.sql');
const docs = readFileSync(new URL('../../docs/trust-and-credentials.md', import.meta.url), 'utf8');
const all = m40 + m41 + m42 + m43;

test('the private evidence bucket is named the same in the migration and the docs', () => {
  assert.match(m40, /'credentials-private'/);
  assert.match(docs, /credentials-private/);
});

test('the six review states in the table, the docs and the transitions agree', () => {
  const states = ['submitted', 'reviewing', 'needs_information', 'approved', 'rejected', 'expired'];
  const check = /review_state in \(([^)]*)\)/.exec(m40)[1].split(',').map((s) => s.trim().replaceAll("'", ''));
  assert.deepEqual(check, states);
  for (const s of states) assert.ok(docs.includes(s), `docs mention ${s}`);
});

test('versioned wording constants are identical everywhere they are checked', () => {
  const notice = new Set(all.match(/credential-notice-v\d+/g));
  assert.deepEqual([...notice], ['credential-notice-v1']);
  assert.ok(docs.includes('credential-notice-v1'));
  const loc = new Set(all.match(/location-v\d+/g));
  assert.deepEqual([...loc], ['location-v2']);
  assert.ok(docs.includes('location-v2'));
});

test('every public function the docs promise is defined, and nothing is granted to anon by accident', () => {
  const fns = [
    'list_credential_queue', 'start_credential_review', 'begin_credential_evidence_view', 'decide_credential',
    'withdraw_credential_decision', 'expire_credential_decisions', 'purge_stale_credential_evidence',
    'get_credential_status', 'resubmit_credential', 'review_listing', 'withdraw_listing_review',
    'get_trust_summary', 'set_location_disclosure', 'get_location_settings',
  ];
  for (const f of fns) {
    assert.match(all, new RegExp(`create function public\\.${f}\\(`), `${f} defined`);
    assert.ok(docs.includes(f), `docs mention ${f}`);
  }
  // Anonymous callers get exactly two things from these migrations: the wording table and the read-only summary.
  assert.equal(all.split(' to anon').length - 1, 2);
});

test('evidence view mints no URL: the database returns bucket, path and a 60 second ttl only', () => {
  assert.match(m40, /'ttlSeconds', 60/);
  assert.doesNotMatch(m40, /createSignedUrl|signedURL/);
});

test('every table that stores user-written text has the safe-text trigger', () => {
  for (const t of ['provider_profiles', 'provider_photos', 'provider_starting_prices', 'provider_healthcare_details',
    'credential_records', 'reports']) {
    assert.match(m43, new RegExp(`trg_safe_text before insert or update on public\\.${t}\\b`), t);
  }
});
