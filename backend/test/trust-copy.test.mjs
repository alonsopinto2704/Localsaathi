// Phase 090: the badge wording in migration 0041 stays truthful. A guard that
// also FAILS on injected over-claims, so a green run means something.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const sql = readFileSync(new URL('../supabase/migrations/20261008000041_truthful_trust_badges.sql', import.meta.url), 'utf8');

const KEYS = ['phone_verified', 'listing_reviewed', 'credential_checked', 'self_reported'];
const LOCALES = ['en', 'hi', 'mr'];
// A label or scope may not promise safety or trust; a limitation sentence may
// say what the badge is NOT ("not a guarantee ... of safety").
const OVERCLAIM = {
  en: /trusted|\bsafe\b|guarantee|certified|endorsed|approved by/i,
  hi: /भरोसेमंद|विश्वसनीय|सुरक्षित|गारंटी|प्रमाणित/,
  mr: /विश्वासार्ह|विश्वासू|सुरक्षित|हमी|प्रमाणित/,
};
const NEGATION = { en: /\bnot\b|\bonly\b/i, hi: /नहीं|केवल/, mr: /नाही|फक्त/ };

export function parseCopy(text) {
  const q = `'((?:[^']|'')*)'`;
  const re = new RegExp(`\\(\\s*${q},\\s*${q},\\s*${q},\\s*${q},\\s*${q}\\)`, 'g');
  const unq = (s) => s.replaceAll("''", "'");
  return [...text.matchAll(re)]
    .filter((m) => KEYS.includes(m[1]) && LOCALES.includes(m[2]))
    .map((m) => ({ key: m[1], locale: m[2], label: unq(m[3]), scope: unq(m[4]), limits: unq(m[5]) }));
}

export function lint(rows) {
  const problems = [];
  for (const k of KEYS) for (const l of LOCALES) {
    if (!rows.some((r) => r.key === k && r.locale === l)) problems.push(`missing ${k}/${l}`);
  }
  for (const r of rows) {
    const id = `${r.key}/${r.locale}`;
    if (OVERCLAIM[r.locale].test(`${r.label} ${r.scope}`)) problems.push(`${id}: label or scope over-claims`);
    if (!NEGATION[r.locale].test(r.limits)) problems.push(`${id}: limits do not state a limitation`);
    if (r.label.length > 40 || r.scope.length > 300 || r.limits.length > 300) problems.push(`${id}: too long`);
  }
  return problems;
}

const rows = parseCopy(sql);

test('the wording table has every badge in every supported language', () => {
  assert.equal(rows.length, KEYS.length * LOCALES.length);
});

test('no label or scope over-claims, and every badge states its limits', () => {
  assert.deepEqual(lint(rows), []);
});

test('phone and credential wording keep their distinct scope', () => {
  const en = Object.fromEntries(rows.filter((r) => r.locale === 'en').map((r) => [r.key, r]));
  assert.match(en.phone_verified.scope, /one-time code/);
  assert.match(en.phone_verified.limits, /not an identity, background or qualification check/);
  assert.match(en.credential_checked.limits, /only that credential and period/);
  assert.match(en.self_reported.scope, /written by the provider/);
  assert.notEqual(en.phone_verified.label, en.credential_checked.label);
});

test('mutation: an over-claiming label or a missing limitation is caught', () => {
  const bad = structuredClone(rows);
  bad.find((r) => r.key === 'phone_verified' && r.locale === 'en').label = 'Trusted provider';
  bad.find((r) => r.key === 'credential_checked' && r.locale === 'hi').scope = 'यह व्यक्ति सुरक्षित है';
  bad.find((r) => r.key === 'listing_reviewed' && r.locale === 'mr').limits = 'पुनरावलोकन झाले';
  assert.equal(lint(bad).length, 3);
  assert.ok(lint(rows.slice(1)).some((p) => p.startsWith('missing')));
});

test('no badge is awarded from client-sent data: no writable verification column exists', () => {
  // The public map is derived by private.trust_overlay from decisions and reviews only.
  assert.match(sql, /create function private\.trust_overlay/);
  assert.doesNotMatch(sql, /grant (insert|update)[^;]*verification_records/i);
});
