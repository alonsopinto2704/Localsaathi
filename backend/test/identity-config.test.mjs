// Phases 056/060: the back-door guard passes on the repo and FAILS on injected
// regressions (mutation checks), so a green run means something.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { checkConfigToml, checkDartSources, checkRepo } from '../scripts/check-identity-config.mjs';

const config = readFileSync(new URL('../supabase/config.toml', import.meta.url), 'utf8');

test('the repository is clean', () => {
  assert.deepEqual(checkRepo(), []);
});

test('mutation: a fixed test OTP block is caught', () => {
  assert.equal(checkConfigToml(`${config}\n[auth.sms.test_otp]\n"+919000099999" = "000000"\n`).length >= 1, true);
});

test('mutation: a phone = code entry without the section header is caught', () => {
  assert.equal(checkConfigToml(`${config}\n"+919000099999" = "123456"\n`).length >= 1, true);
});

test('mutation: an inline hook secret, enabled hook without env secret, and a pasted JWT are caught', () => {
  assert.ok(checkConfigToml(config.replace('secrets = "env(SEND_SMS_HOOK_SECRET)"', 'secrets = "v1,whsec_abcdefabcdef"')).length >= 1);
  assert.ok(checkConfigToml(config.replace('enabled = false\nuri', 'enabled = true\nuri').replace('secrets = "env(SEND_SMS_HOOK_SECRET)"', '')).length >= 1);
  assert.ok(checkConfigToml(`${config}\nanon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"\n`).length >= 1);
});

test('comments mentioning the forbidden words do not trip the guard', () => {
  assert.deepEqual(checkConfigToml(`# [auth.sms.test_otp]\n# "+919000099999" = "000000"\n${config}`), []);
});

test('mutation: Dart code outside the demo graph reading the OTP constant, or a service-role key, is caught', () => {
  assert.equal(checkDartSources({ 'lib/data/supabase/x.dart': 'final c = AppConfig.developmentOtpCode;' }).length, 1);
  assert.equal(checkDartSources({ 'lib/core/config/app_config.dart': 'static const String developmentOtpCode = "1";' }).length, 0);
  assert.equal(checkDartSources({ 'lib/a.dart': 'const key = SERVICE_ROLE_KEY;' }).length, 1);
});
