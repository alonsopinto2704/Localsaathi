// Phases 056/060: static guard against identity back doors reaching a hosted
// project or a release build. Pure checks over text so they can be unit
// tested and mutation tested (backend/test/identity-config.test.mjs).
//
//   node backend/scripts/check-identity-config.mjs        (exit 1 on any problem)
//
// What it enforces:
//  * supabase/config.toml has no [auth.sms.test_otp] block and no phone-looking
//    key (a fixed code pushed with `supabase config push` is a permanent
//    back door);
//  * the Send SMS hook secret is read from the environment, never inline, and
//    no secret-looking literal is in config.toml;
//  * with --production (or LS_ENV=production): [auth.hook.send_sms] must be
//    enabled with secrets = "env(...)" and an https uri, because the per-number,
//    per-block and global OTP limits and the breaker run only inside that hook;
//    local/demo config keeps it disabled and still passes;
//  * the Flutter app never refers to a service-role key;
//  * the simulated OTP is reachable only from files that are part of the demo
//    graph (AppConfig + the mock auth repository), so production code paths
//    cannot read the fixed code.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const stripToml = (text) => text.split('\n').map((l) => l.replace(/(^|\s)#.*$/, '')).join('\n');

export function checkConfigToml(text, { production = false } = {}) {
  const problems = [];
  const live = stripToml(text);
  if (/^\s*\[auth\.sms\.test_otp\]/m.test(live)) problems.push('config.toml defines [auth.sms.test_otp] (fixed OTP could be pushed to a hosted project)');
  if (/^\s*"?\+?\d{8,15}"?\s*=\s*"?\d{4,8}"?\s*$/m.test(live)) problems.push('config.toml has a phone-number = code entry');
  const hook = /\[auth\.hook\.send_sms\][^[]*/m.exec(live)?.[0] ?? '';
  if (/enabled\s*=\s*true/.test(hook) && !/secrets\s*=\s*"env\([A-Z_]+\)"/.test(hook)) problems.push('send_sms hook is enabled without secrets = "env(...)"');
  if (production) {
    if (!/enabled\s*=\s*true/.test(hook)) problems.push('production: [auth.hook.send_sms] is not enabled (OTP gate and circuit breaker would not run)');
    if (!/secrets\s*=\s*"env\([A-Z_]+\)"/.test(hook)) problems.push('production: [auth.hook.send_sms] secrets is not env(...)');
    if (!/uri\s*=\s*"https:\/\//.test(hook)) problems.push('production: [auth.hook.send_sms] uri is not https');
  }
  if (/secrets\s*=\s*"(?!env\()/.test(live)) problems.push('a hook secret is written inline instead of env(...)');
  if (/(service_role|eyJ[A-Za-z0-9_-]{20,}|whsec_)/.test(live)) problems.push('config.toml contains a secret-looking literal');
  return problems;
}

export function checkDartSources(files) {
  const problems = [];
  const demoOnly = /(^|\/)lib\/(core\/config\/app_config\.dart|data\/repositories\/mock_auth_repository\.dart|features\/provider\/onboarding\/onboarding_widgets\.dart)$/;
  for (const [path, text] of Object.entries(files)) {
    if (/service_role|SERVICE_ROLE/.test(text.replace(/'service_role'/g, ''))) problems.push(`${path}: refers to a service-role key`);
    if (/\b(developmentOtpCode|useDevelopmentOtpSimulation)\b/.test(text) && !demoOnly.test(path)) {
      problems.push(`${path}: reads the simulated-OTP constants outside the demo graph`);
    }
  }
  return problems;
}

function walk(dir, ext, out = {}) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, ext, out);
    else if (name.endsWith(ext)) out[relative(root, p).replaceAll('\\', '/')] = readFileSync(p, 'utf8');
  }
  return out;
}

export function checkRepo(opts = {}) {
  return [
    ...checkConfigToml(readFileSync(join(root, 'backend/supabase/config.toml'), 'utf8'), opts),
    ...checkDartSources(walk(join(root, 'lib'), '.dart')),
  ];
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const production = process.argv.includes('--production') || process.env.LS_ENV === 'production';
  const problems = checkRepo({ production });
  if (problems.length) {
    console.log(`Identity config: FAIL\n${problems.map((p) => `  - ${p}`).join('\n')}`);
    process.exitCode = 1;
  } else {
    console.log(`Identity config${production ? ' (production profile)' : ''}: PASS (no fixed OTP in config.toml, no inline hook secret, no service-role key or simulated-OTP read in lib/)`);
  }
}
