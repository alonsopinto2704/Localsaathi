// Diagnostic: verify every package in .dart_tool/package_config.json resolves
// to an existing directory on disk, so flutter analyze's URI errors can be
// attributed to a broken package config rather than to source code.
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const cfg = JSON.parse(readFileSync('.dart_tool/package_config.json', 'utf8'));
console.log('generated:', cfg.generated);
let bad = 0;
for (const p of cfg.packages) {
  let dir;
  try {
    dir = fileURLToPath(p.rootUri);
  } catch {
    console.log('BAD URI', p.name, p.rootUri);
    bad++;
    continue;
  }
  if (!existsSync(dir)) {
    console.log('MISSING DIR', p.name, dir);
    bad++;
  }
}
console.log(`checked ${cfg.packages.length} packages, ${bad} broken`);
