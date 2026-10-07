// Captures the Play Store phone screenshots from the Flutter web build.
//
//   cd tool/screenshots && npm install && node capture.mjs [name-filter]
//
// Serves ../../build/web on a free local port, drives the installed Chrome
// headlessly at a 360x640 CSS viewport with deviceScaleFactor 3 (= 1080x1920),
// and writes store/screenshots/phone/raw/NN-name.png. Does not build anything.
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer-core';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const WEB = path.join(ROOT, 'build', 'web');
const OUT = path.join(ROOT, 'store', 'screenshots', 'phone', 'raw');
const CHROME = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
// An Android UA makes Flutter use its Android behaviour (no desktop scrollbars).
const UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Mobile Safari/537.36';

// First-run state. shared_preferences on web = localStorage, keys prefixed
// "flutter.", values JSON-encoded (shared_preferences_web). Keys and value
// shapes: lib/data/local/key_value_store.dart, app_settings_controller.dart,
// location_controller.dart. The stored locality is re-resolved by id on start.
const PREFS = {
  'localsaathi.onboarding_completed': 'true', // skips the welcome/locality step
  'localsaathi.selected_location': JSON.stringify({ cityId: 'mh-mumbai', localityId: 'mh-mumbai-andheri-west' }),
};

// Provider sign-in for the listing-editor shot. The current build simulates
// OTP (AppConfig.developmentOtpCode); a Supabase build needs the reviewer test
// number and its fixed code (docs/deploy/play-console.md, "App access").
const PHONE = process.env.LS_TEST_PHONE || '9876543210';
const OTP = process.env.LS_TEST_OTP || '123456';
// A listing that shows photos and an opted-in map pin. Change after a rebuild
// with different data.
const PROFILE = process.env.LS_PROFILE || 'Dr. Farah Sheikh';

const SHOTS = [
  ['01-home', '/', []],
  ['02-results', '/', [tap('Plumber')]],
  ['03-profile', '/', [tap('Search for a service'), type('dentist'), tap(PROFILE), scrollTo('Location')]],
  ['04-map', '/', [tap('Search for a service'), type('clinic'), tap('Show map')]],
  ['05-saved', '/', [tap('Save', { role: 'button' }), tap('Save', { role: 'button', nth: 1 }), tap('Saved', { role: 'tab' })]],
  ['06-listing', '/provider/onboarding', [tap('Phone number'), type(PHONE), tap('Send code'), tap('One-time code'), type(OTP), tap('Verify and continue')]],
];

// ------------------------------------------------------------------ steps
function tap(label, { role, nth = 0 } = {}) {
  return async (page) => {
    const p = await find(page, label, role, nth);
    await page.mouse.click(p.x, p.y);
    await settle(page);
  };
}

function type(text) {
  return async (page) => {
    await page.keyboard.type(text, { delay: 30 });
    await page.keyboard.press('Enter');
    await settle(page);
  };
}

// Wheel-scrolls until the element labelled `label` sits in the upper part of the screen.
function scrollTo(label) {
  return async (page) => {
    for (let i = 0; i < 40; i++) {
      const p = await find(page, label, undefined, 0, 500).catch(() => null);
      if (p && p.y < 260) break;
      await page.mouse.move(180, 400);
      await page.mouse.wheel({ deltaY: p ? Math.min(160, p.y - 160) : 160 });
      await sleep(150);
    }
    await settle(page);
  };
}

// Flutter web mirrors its semantics tree as <flt-semantics> elements. Picks
// the smallest on-screen element whose label starts with `label`.
async function find(page, label, role, nth = 0, timeout = 15000) {
  const handle = await page.waitForFunction((label, role, nth) => {
    const hits = [];
    for (const e of document.querySelectorAll('flt-semantics')) {
      const text = (e.getAttribute('aria-label') || e.textContent || '').trim();
      if (!text.startsWith(label) || (role && e.getAttribute('role') !== role)) continue;
      const b = e.getBoundingClientRect();
      if (b.width && b.height && b.top >= 0 && b.bottom <= innerHeight) hits.push({ x: b.x + b.width / 2, y: b.y + b.height / 2, area: b.width * b.height, top: b.top });
    }
    // Same-label nodes nest (group > button); keep the innermost per position.
    const inner = hits.sort((a, b) => a.area - b.area).filter((h, i, all) => all.findIndex((o) => Math.abs(o.x - h.x) < 2 && Math.abs(o.y - h.y) < 2) === i);
    return inner.sort((a, b) => a.top - b.top)[nth] || null;
  }, { timeout, polling: 200 }, label, role, nth);
  return handle.jsonValue();
}

// Done when the network is quiet (fonts, map tiles) and two consecutive frames match.
async function settle(page) {
  await page.waitForNetworkIdle({ idleTime: 600, timeout: 30000 }).catch(() => {});
  let last = null;
  for (let i = 0; i < 40; i++) {
    await sleep(250);
    const shot = Buffer.from(await page.screenshot());
    if (last && shot.equals(last)) return shot;
    last = shot;
  }
  console.warn('  screen never settled; using the last frame');
  return last;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ------------------------------------------------------------------ server
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf' };
function serve() {
  const server = http.createServer((req, res) => {
    const rel = decodeURIComponent(new URL(req.url, 'http://localhost').pathname).replace(/\/$/, '/index.html');
    const file = path.join(WEB, path.normalize(rel));
    if (!file.startsWith(WEB)) return res.writeHead(403).end();
    fs.readFile(file, (err, data) => {
      if (err) return res.writeHead(404).end();
      res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
      res.end(data);
    });
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server))); // port 0 = any free port
}

// ------------------------------------------------------------------ main
if (!fs.existsSync(path.join(WEB, 'index.html'))) {
  console.error(`No web build at ${WEB}. Run "flutter build web --release" first.`);
  process.exit(1);
}
fs.mkdirSync(OUT, { recursive: true });
const filter = process.argv[2] || '';
const server = await serve();
const base = `http://127.0.0.1:${server.address().port}/`;
const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--hide-scrollbars', '--no-first-run'] });
let failed = 0;
try {
  for (const [name, route, steps] of SHOTS.filter(([n]) => n.includes(filter))) {
    const context = await browser.createBrowserContext(); // fresh localStorage per shot
    const page = await context.newPage();
    try {
      await page.setUserAgent(UA);
      await page.setViewport({ width: 360, height: 640, deviceScaleFactor: 3, isMobile: true, hasTouch: true });
      await page.evaluateOnNewDocument((prefs) => {
        for (const [k, v] of Object.entries(prefs)) localStorage.setItem(`flutter.${k}`, JSON.stringify(v));
      }, PREFS);
      await page.goto(base + (route === '/' ? '' : `#${route}`), { waitUntil: 'networkidle0', timeout: 60000 });
      await page.waitForSelector('flt-semantics-placeholder', { timeout: 30000 });
      // Turn on the semantics tree so steps can find widgets by label. Flutter's
      // mobile enabler wants a click on the centre of its placeholder.
      await page.evaluate(() => {
        const e = document.querySelector('flt-semantics-placeholder');
        const b = e.getBoundingClientRect();
        e.dispatchEvent(new MouseEvent('click', { clientX: b.x + b.width / 2, clientY: b.y + b.height / 2, bubbles: true }));
      });
      await page.waitForSelector('flt-semantics', { timeout: 10000 });
      await settle(page);
      for (const step of steps) await step(page);
      fs.writeFileSync(path.join(OUT, `${name}.png`), await settle(page));
      console.log('captured', name);
    } catch (err) {
      failed++;
      console.error(`FAILED ${name}: ${err.message}`);
      await page.screenshot({ path: path.join(OUT, `${name}.failed.png`) }).catch(() => {});
    } finally {
      await context.close();
    }
  }
} finally {
  await browser.close();
  server.close();
}
process.exit(failed ? 1 : 0);
