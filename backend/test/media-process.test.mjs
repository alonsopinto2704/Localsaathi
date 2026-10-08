// Phases 083, 084, 086: content validation, metadata stripping, derivatives and
// budgets. Fixtures are SYNTHETIC byte builders (no real photos): known metadata
// markers are planted, then searched for in every byte written to "public".
// The codec is a FAKE (the real ImageMagick WASM one is unverified until deployed),
// so these tests prove the pipeline around it, not pixel decoding.
import assert from 'node:assert/strict';
import { crc32, deflateSync } from 'node:zlib';
import { test } from 'node:test';
import { handleProcess, makeDerivatives } from '../supabase/functions/media-process/logic.ts';
import { inspect, isClean, strip, tiffOrientation } from '../supabase/functions/media-process/image.ts';

const enc = (s) => new TextEncoder().encode(s);
const cat = (...p) => Uint8Array.from(p.flatMap((x) => [...x]));
const be16 = (n) => [(n >> 8) & 255, n & 255];
const be32 = (n) => [(n >>> 24) & 255, (n >>> 16) & 255, (n >>> 8) & 255, n & 255];
const le32 = (n) => [n & 255, (n >> 8) & 255, (n >> 16) & 255, (n >>> 24) & 255];
const has = (bytes, s) => Buffer.from(bytes).includes(Buffer.from(s));

// Markers a privacy review cares about.
const GPS = 'GPS-LAT-28.6139N-LON-77.2090E';
const CAMERA = 'SERIAL-CAM-8842-OWNER-RAMESH';
const COMMENT = 'comment-home-address-12-MG-Road';
const THUMB = 'EMBEDDED-JFIF-THUMBNAIL';
const TRAIL = 'TRAILING-PAYLOAD-MZ-EXE';
const ALL = [GPS, CAMERA, COMMENT, THUMB, TRAIL, 'PNG-AUTHOR-RAMESH', 'PNG-TIM', 'WEBP-XMP-OWNER', 'WEBP-ICC-PROFILE'];

function tiff(orientation, extra = '') {
  // big-endian TIFF with one orientation entry, then free text (GPS/camera strings) after the IFD
  return cat(enc('MM'), be16(42), be32(8), be16(1), be16(0x0112), be16(3), be32(1), be16(orientation), be16(0), be32(0), enc(extra));
}
const seg = (marker, payload) => cat([0xff, marker], be16(payload.length + 2), payload);
const ENTROPY = cat([0x12, 0xff, 0x00, 0x34, 0xff, 0xd0, 0x56, 0x78]); // stuffed FF00 and an RSTn inside the scan

function jpeg({ w = 640, h = 480, orientation = 1, meta = true, trailing = true, eoi = true } = {}) {
  return cat(
    [0xff, 0xd8],
    meta ? seg(0xe0, cat(enc('JFIF\0'), [1, 1, 0, 0, 1, 0, 1, 0, 0], enc(THUMB))) : [],
    meta ? seg(0xe1, cat(enc('Exif\0\0'), tiff(orientation, `${GPS}|${CAMERA}`))) : [],
    meta ? seg(0xfe, enc(COMMENT)) : [],
    seg(0xdb, cat([0], new Uint8Array(64).fill(8))),
    seg(0xc0, cat([8], be16(h), be16(w), [3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1])),
    seg(0xc4, cat([0], new Uint8Array(16), [0])),
    seg(0xda, cat([3, 1, 0, 2, 0x11, 3, 0x11, 0, 63, 0])),
    ENTROPY,
    eoi ? [0xff, 0xd9] : [],
    trailing ? enc(TRAIL) : [],
  );
}

const chunk = (type, data) => cat(be32(data.length), enc(type), data, be32(crc32(cat(enc(type), data))));
function png({ w = 320, h = 240, orientation = 0, meta = true, badCrc = false, noIend = false, bomb = false } = {}) {
  const raw = bomb ? new Uint8Array(10) : new Uint8Array(h * (w * 3 + 1));
  let c = chunk('IDAT', deflateSync(raw));
  return cat(
    [137, 80, 78, 71, 13, 10, 26, 10],
    chunk('IHDR', cat(be32(w), be32(h), [8, 2, 0, 0, 0])),
    meta ? chunk('tEXt', enc('Author\0PNG-AUTHOR-RAMESH')) : [],
    meta ? chunk('tIME', cat(enc('PNG-TIM').subarray(0, 7))) : [],
    meta && orientation ? chunk('eXIf', tiff(orientation, `${GPS}|${CAMERA}`)) : [],
    chunk('sRGB', [0]),
    badCrc ? cat(c.subarray(0, c.length - 1), [c[c.length - 1] ^ 1]) : c,
    noIend ? [] : chunk('IEND', []),
    meta ? enc(TRAIL) : [],
  );
}

function webp({ w = 320, h = 240, orientation = 0, meta = true, badSize = false } = {}) {
  const pad = (d) => (d.length % 2 ? cat(d, [0]) : d);
  const ck = (t, d) => cat(enc(t), le32(d.length), pad(d));
  const vp8l = cat([0x2f], le32((w - 1) | ((h - 1) << 14)), new Uint8Array(12).fill(7));
  const flags = meta ? 0x20 | 0x08 | 0x04 : 0;
  const body = cat(
    enc('WEBP'),
    ck('VP8X', cat([flags, 0, 0, 0], le32(w - 1).slice(0, 3), le32(h - 1).slice(0, 3))),
    meta ? ck('ICCP', enc('WEBP-ICC-PROFILE')) : [],
    ck('VP8L', vp8l),
    meta ? ck('EXIF', tiff(orientation || 1, `${GPS}|${CAMERA}`)) : [],
    meta ? ck('XMP ', enc('WEBP-XMP-OWNER')) : [],
  );
  return cat(enc('RIFF'), le32(body.length + (badSize ? 5 : 0)), body);
}

// --- container checks --------------------------------------------------------
test('format comes from the bytes: a renamed executable, HTML and SVG are not images', async () => {
  for (const bytes of [cat(enc('MZ\x90\x00'), new Uint8Array(500)), enc('<html><script>alert(1)</script></html>'), enc('<svg xmlns="http://www.w3.org/2000/svg"/>'), enc('%PDF-1.7')]) {
    await assert.rejects(() => makeDerivatives(bytes, 'image/jpeg', 1e6, POLICY, fakeCodec().codec), { code: 'not_an_image' });
  }
});

test('client-declared type must match the content', async () => {
  await assert.rejects(() => makeDerivatives(png(), 'image/jpeg', 1e6, POLICY, fakeCodec().codec), { code: 'mime_mismatch' });
});

test('malformed or truncated files are refused', async () => {
  const bad = [
    [jpeg({ eoi: false, trailing: false }), 'image/jpeg'],
    [jpeg().subarray(0, 40), 'image/jpeg'],
    [png({ badCrc: true }), 'image/png'],
    [png({ noIend: true, meta: false }), 'image/png'],
    [webp({ badSize: true }), 'image/webp'],
    [cat([0xff, 0xd8, 0xff, 0xd9]), 'image/jpeg'],
  ];
  for (const [bytes, mime] of bad) {
    await assert.rejects(() => makeDerivatives(bytes, mime, 1e6, POLICY, fakeCodec().codec), { code: 'malformed' });
  }
});

test('decompression bombs are refused from the header, and the codec never runs', async () => {
  const f = fakeCodec();
  await assert.rejects(() => makeDerivatives(png({ w: 60000, h: 60000, bomb: true }), 'image/png', 1e6, POLICY, f.codec), { code: 'dimensions_too_large' });
  await assert.rejects(() => makeDerivatives(jpeg({ w: 30000, h: 30000 }), 'image/jpeg', 1e6, POLICY, f.codec), { code: 'dimensions_too_large' });
  await assert.rejects(() => makeDerivatives(webp({ w: 16000, h: 16000 }), 'image/webp', 1e6, POLICY, f.codec), { code: 'dimensions_too_large' });
  assert.equal(f.calls.length, 0);
});

test('size limits apply to the bytes actually received', async () => {
  await assert.rejects(() => makeDerivatives(jpeg(), 'image/jpeg', 100, POLICY, fakeCodec().codec), { code: 'too_large' });
  await assert.rejects(() => makeDerivatives(new Uint8Array(0), 'image/jpeg', 100, POLICY, fakeCodec().codec), { code: 'too_large' });
});

// --- stripping ---------------------------------------------------------------
test('JPEG: GPS, camera, comment, JFIF thumbnail and trailing bytes are gone; image data and orientation survive', () => {
  const src = jpeg({ orientation: 6 });
  for (const m of [GPS, CAMERA, COMMENT, THUMB, TRAIL]) assert.ok(has(src, m), `fixture carries ${m}`);
  const out = strip(src, 'image/jpeg');
  for (const m of ALL) assert.ok(!has(out, m), `${m} removed`);
  assert.ok(has(out, ENTROPY), 'entropy-coded data is byte-identical');
  assert.equal(inspect(out, 'image/jpeg').orientation, 6, 'orientation kept');
  assert.equal(inspect(out, 'image/jpeg').width, 640);
  assert.ok(isClean(out, 'image/jpeg'), 'stripping is idempotent');
  assert.ok(!isClean(src, 'image/jpeg'));
  assert.equal(tiffOrientation(enc('garbage')), 1, 'unreadable EXIF falls back to upright, never throws');
});

test('PNG: text, time and EXIF chunks and trailing bytes are gone; critical data and CRCs are intact', () => {
  const src = png({ orientation: 3 });
  assert.ok(has(src, 'PNG-AUTHOR-RAMESH') && has(src, GPS));
  const out = strip(src, 'image/png');
  for (const m of ALL) assert.ok(!has(out, m), `${m} removed`);
  assert.equal(inspect(out, 'image/png').width, 320);
  assert.ok(isClean(out, 'image/png'));
  assert.equal(inspect(src, 'image/png').orientation, 3);
});

test('WebP: ICC, EXIF and XMP chunks are gone, VP8X flags cleared, RIFF size consistent', () => {
  const src = webp({ orientation: 8 });
  const out = strip(src, 'image/webp');
  for (const m of ALL) assert.ok(!has(out, m), `${m} removed`);
  assert.equal(new DataView(out.buffer, out.byteOffset).getUint32(4, true) + 8, out.length);
  assert.equal(out[20] & (0x20 | 0x08 | 0x04), 0, 'metadata flags cleared');
  assert.ok(isClean(out, 'image/webp'));
  assert.equal(inspect(src, 'image/webp').orientation, 8);
});

// --- derivatives -------------------------------------------------------------
const POLICY = { derivatives: [
  { kind: 'thumb', maxEdge: 320, maxBytes: 40960, quality: 70 },
  { kind: 'full', maxEdge: 1280, maxBytes: 307200, quality: 80 },
] };

/** A fake codec: returns a valid synthetic WebP scaled to maxEdge. `leak` plants metadata in its output. */
function fakeCodec({ leak = false, fail = false } = {}) {
  const calls = [];
  return {
    calls,
    codec: {
      async resize(_src, mime, { maxEdge, quality }) {
        calls.push({ mime, maxEdge, quality });
        if (fail) throw new Error('decoder crashed');
        return webp({ w: Math.min(maxEdge, 4000), h: Math.round(maxEdge * 0.75), meta: leak });
      },
    },
  };
}

test('small JPEG: thumbnail is re-encoded, the full image is the stripped original (no pixel loss)', async () => {
  const f = fakeCodec();
  const { thumb, full } = await makeDerivatives(jpeg({ w: 800, h: 600 }), 'image/jpeg', 1e6, POLICY, f.codec);
  assert.deepEqual(f.calls.map((c) => c.maxEdge), [320]);
  assert.equal(full.mime, 'image/jpeg');
  assert.ok(has(full.bytes, ENTROPY) && !has(full.bytes, GPS));
  assert.equal(thumb.mime, 'image/webp');
  assert.ok(thumb.bytes.length <= 40960 && full.bytes.length <= 307200);
});

test('large image: both derivatives go through the codec at their edge limits and are scanned again', async () => {
  const f = fakeCodec({ leak: true }); // the codec "forgets" to strip: the pipeline must not publish that
  const { thumb, full } = await makeDerivatives(jpeg({ w: 3000, h: 2000 }), 'image/jpeg', 1e7, POLICY, f.codec);
  assert.deepEqual(f.calls.map((c) => c.maxEdge), [320, 1280]);
  for (const d of [thumb, full]) {
    for (const m of ALL) assert.ok(!has(d.bytes, m), `${m} absent from ${d.mime} derivative`);
    assert.ok(isClean(d.bytes, d.mime));
  }
});

test('non-JPEG with a non-default orientation is re-encoded (pixels rotated), not passed through', async () => {
  const f = fakeCodec();
  await makeDerivatives(png({ orientation: 6 }), 'image/png', 1e6, POLICY, f.codec);
  assert.deepEqual(f.calls.map((c) => c.maxEdge), [320, 1280]);
});

test('over-budget codec output is retried once at lower quality, then refused', async () => {
  // A codec returning a lossless-sized image: a VP8L chunk with a large body.
  const bigWebp = () => {
    const pad = (d) => (d.length % 2 ? cat(d, [0]) : d);
    const vp8l = cat([0x2f], le32(319 | (239 << 14)), new Uint8Array(60000).fill(5));
    const body = cat(enc('WEBP'), enc('VP8L'), le32(vp8l.length), pad(vp8l));
    return cat(enc('RIFF'), le32(body.length), body);
  };
  const calls = [];
  const codec = { async resize(_s, _m, o) { calls.push(o.quality); return bigWebp(); } };
  await assert.rejects(() => makeDerivatives(jpeg({ w: 3000, h: 2000 }), 'image/jpeg', 1e7, POLICY, codec), { code: 'over_budget' });
  assert.deepEqual(calls, [70, 50], 'thumbnail tried at quality 70 then 50, then refused');
});

test('a decoder crash is a processing fault (retriable), not a verdict on the file', async () => {
  await assert.rejects(() => makeDerivatives(jpeg({ w: 3000, h: 2000 }), 'image/jpeg', 1e7, POLICY, fakeCodec({ fail: true }).codec), /decoder crashed/);
});

// --- the handler -------------------------------------------------------------
const U = '11111111-2222-4333-8444-555555555555';
const PROFILE = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const OWNER = '00000000-0000-0000-0000-00000000000a';

function world({ file = jpeg({ w: 800, h: 600 }), begin, codec = fakeCodec().codec, putFails = false, completeFails = false, missing = false } = {}) {
  const w = { public: new Map(), removedPublic: [], removedOriginal: [], rejected: [], completed: [], downloads: [], mimeDeclared: 'image/jpeg' };
  w.deps = {
    codec,
    authenticate: async (jwt) => (jwt === 'tok-owner' ? OWNER : null),
    begin: async (id, user) => begin ? begin(id, user) : user === OWNER && id === U
      ? { ok: true, status: 'processing', profileId: PROFILE, bucket: 'media-quarantine', path: `${PROFILE}/${U}`, mime: w.mimeDeclared, maxBytes: 1e6 }
      : { ok: false, code: 'not_found' },
    policy: async () => POLICY,
    download: async (b, p) => { w.downloads.push(`${b}:${p}`); return missing ? null : file; },
    putPublic: async (p, bytes, mime) => { if (putFails && w.public.size >= 1) return false; w.public.set(p, { bytes, mime }); return true; },
    removePublic: async (ps) => { w.removedPublic.push(...ps); for (const p of ps) w.public.delete(p); },
    removeOriginal: async (b, p) => { w.removedOriginal.push(`${b}:${p}`); },
    complete: async (a) => { if (completeFails) return false; w.completed.push(a); return true; },
    reject: async (id, code, retry) => { w.rejected.push({ id, code, retry }); },
  };
  return w;
}
const call = (w, { token = 'tok-owner', body = { uploadId: U }, method = 'POST' } = {}) =>
  handleProcess({ method, authorization: token ? `Bearer ${token}` : null, body: JSON.stringify(body) }, w.deps);

test('happy path: keys come from the upload id, nothing sensitive is public, the original is deleted', async () => {
  const w = world({ file: jpeg({ w: 800, h: 600, orientation: 6 }) });
  const res = await call(w);
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'approved');
  assert.match(res.body.thumbPath, new RegExp(`^${PROFILE}/${U}-thumb\\.webp$`));
  assert.match(res.body.fullPath, new RegExp(`^${PROFILE}/${U}-full\\.jpg$`));
  assert.equal(w.public.size, 2);
  for (const { bytes } of w.public.values()) for (const m of ALL) assert.ok(!has(bytes, m), `${m} absent from public bytes`);
  assert.deepEqual(w.downloads, [`media-quarantine:${PROFILE}/${U}`], 'the path came from the stored row');
  assert.deepEqual(w.removedOriginal, [`media-quarantine:${PROFILE}/${U}`]);
  assert.equal(w.completed.length, 1);
  assert.ok(w.completed[0].thumbBytes <= 40960 && w.completed[0].fullBytes <= 307200);
});

test('a rejected file never reaches public storage; the original is removed and a short code recorded', async () => {
  const w = world({ file: enc('MZ not an image at all') });
  const res = await call(w);
  assert.equal(res.status, 422);
  assert.deepEqual(res.body, { error: 'not_an_image' });
  assert.equal(w.public.size, 0);
  assert.deepEqual(w.rejected, [{ id: U, code: 'not_an_image', retry: false }]);
  assert.equal(w.removedOriginal.length, 1);
});

test('the body cannot choose a path or owner; unknown fields are ignored', async () => {
  const w = world();
  await call(w, { body: { uploadId: U, path: 'other-profile/steal.jpg', userId: 'victim', bucket: 'provider-photos' } });
  assert.deepEqual(w.downloads, [`media-quarantine:${PROFILE}/${U}`]);
});

test('another account, anonymous callers and bad input never reach storage', async () => {
  const w = world();
  assert.equal((await call(w, { token: null })).status, 401);
  assert.equal((await call(w, { token: 'tok-other' })).status, 401);
  assert.equal((await call(w, { method: 'GET' })).status, 405);
  assert.equal((await call(w, { body: { uploadId: 'not-a-uuid' } })).status, 400);
  const other = world({ begin: async () => ({ ok: false, code: 'not_found' }) });
  assert.equal((await call(other)).status, 404);
  assert.equal(w.downloads.length + other.downloads.length, 0);
});

test('transient faults clean up whatever was written and leave the upload retriable', async () => {
  for (const opts of [{ putFails: true }, { completeFails: true }, { missing: true }, { codec: fakeCodec({ fail: true }).codec, file: jpeg({ w: 3000, h: 2000 }) }]) {
    const w = world(opts);
    const res = await call(w);
    assert.equal(res.status, 502);
    assert.deepEqual(res.body, { error: 'processing_failed' }, 'no internal detail leaks');
    assert.equal(w.public.size, 0, 'nothing public is left behind');
    assert.deepEqual(w.rejected.map((r) => r.retry), [true]);
    assert.equal(w.removedOriginal.length, 0, 'the original is kept so a retry can run');
  }
});

test('database refusals map to stable statuses; an approved upload is idempotent', async () => {
  assert.equal((await call(world({ begin: async () => ({ ok: false, code: 'expired' }) }))).status, 410);
  assert.equal((await call(world({ begin: async () => ({ ok: false, code: 'rejected', detail: 'too_large' }) }))).status, 422);
  const again = world({ begin: async () => ({ ok: true, status: 'approved' }) });
  assert.equal((await call(again)).status, 200);
  assert.equal(again.downloads.length, 0);
});
