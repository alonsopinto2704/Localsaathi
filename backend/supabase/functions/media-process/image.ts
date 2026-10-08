// Image container checks and metadata stripping (phases 083-084). Pure
// TypeScript, no dependencies: runs under Deno (index.ts) and Node
// (backend/test/media-process.test.mjs). Port and extension of
// lib/core/utils/image_metadata.dart, which stays as a client-side optimisation.
//
// What this does: identify the format from the BYTES (never the name or the
// declared type), walk the container strictly (truncated, malformed or
// inconsistent files are refused), read the dimensions from the header BEFORE
// anything decodes pixels (decompression-bomb guard), and rewrite the container
// with an allow-list of segments/chunks. EXIF, XMP, IPTC, comments, text and
// timestamp chunks, ICC profiles, JFIF thumbnails and any bytes after the end
// marker are dropped. A JPEG keeps only an orientation-only EXIF block so
// portrait photos stay upright; other formats with a non-default orientation are
// reported so the caller re-encodes them (pixels rotated).
//
// What this does NOT do: decode pixels. Whether the compressed stream itself
// decodes is only known by the codec in index.ts (unverified until deployed).

export type Mime = "image/jpeg" | "image/png" | "image/webp";

export class ProcessError extends Error {
  code: string;
  constructor(code: string) {
    super(code);
    this.code = code;
  }
}

export const MAX_EDGE = 8000;
export const MAX_PIXELS = 16_000_000;

export interface Info {
  mime: Mime;
  width: number;
  height: number;
  orientation: number; // 1 = upright / unknown
}

export function sniff(b: Uint8Array): Mime | null {
  if (b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "image/jpeg";
  if (b.length > 8 && PNG_SIG.every((v, i) => b[i] === v)) return "image/png";
  if (b.length > 12 && ascii(b, 0, 4) === "RIFF" && ascii(b, 8, 4) === "WEBP") return "image/webp";
  return null;
}

/** Validates the container and returns its facts, or throws ProcessError. */
export function inspect(b: Uint8Array, mime: Mime): Info {
  const r = mime === "image/jpeg" ? walkJpeg(b) : mime === "image/png" ? walkPng(b) : walkWebp(b);
  if (r.width < 1 || r.height < 1) throw new ProcessError("malformed");
  if (r.width > MAX_EDGE || r.height > MAX_EDGE || r.width * r.height > MAX_PIXELS) {
    throw new ProcessError("dimensions_too_large");
  }
  return { mime, width: r.width, height: r.height, orientation: r.orientation };
}

/** The same image with only the allow-listed structure; always valid input to inspect(). */
export function strip(b: Uint8Array, mime: Mime): Uint8Array {
  return mime === "image/jpeg" ? stripJpeg(b) : mime === "image/png" ? stripPng(b) : stripWebp(b);
}

/** True when stripping would change nothing: the gate for every public derivative. */
export function isClean(b: Uint8Array, mime: Mime): boolean {
  const s = strip(b, mime);
  return s.length === b.length && s.every((v, i) => v === b[i]);
}

// --- helpers ---------------------------------------------------------------
const PNG_SIG = [137, 80, 78, 71, 13, 10, 26, 10];
const ascii = (b: Uint8Array, at: number, n: number) => String.fromCharCode(...b.subarray(at, at + n));
const u16 = (b: Uint8Array, i: number) => (b[i] << 8) | b[i + 1];
const u32 = (b: Uint8Array, i: number) => ((b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]) >>> 0;
const le32 = (b: Uint8Array, i: number) => (b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)) >>> 0;
const concat = (parts: Uint8Array[]) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) { out.set(p, at); at += p.length; }
  return out;
};

/** Orientation (1-8) from a TIFF block, or 1 when absent/unreadable. Bounds-checked. */
export function tiffOrientation(t: Uint8Array): number {
  if (t.length >= 6 && ascii(t, 0, 4) === "Exif") t = t.subarray(6);
  if (t.length < 14) return 1;
  const le = t[0] === 0x49 && t[1] === 0x49;
  if (!le && !(t[0] === 0x4d && t[1] === 0x4d)) return 1;
  const g16 = (i: number) => (le ? t[i] | (t[i + 1] << 8) : (t[i] << 8) | t[i + 1]);
  const g32 = (i: number) => (le ? le32(t, i) : u32(t, i));
  const ifd = g32(4);
  if (ifd + 2 > t.length) return 1;
  const n = g16(ifd);
  for (let k = 0; k < n; k++) {
    const e = ifd + 2 + k * 12;
    if (e + 12 > t.length) return 1;
    if (g16(e) === 0x0112) {
      const v = g16(e + 8);
      return v >= 1 && v <= 8 ? v : 1;
    }
  }
  return 1;
}

function orientationExif(o: number): Uint8Array {
  return Uint8Array.from([
    0xff, 0xe1, 0x00, 0x22, 0x45, 0x78, 0x69, 0x66, 0, 0, // APP1 "Exif\0\0"
    0x4d, 0x4d, 0x00, 0x2a, 0, 0, 0, 8, // big-endian TIFF, IFD0 at 8
    0x00, 0x01, 0x01, 0x12, 0x00, 0x03, 0, 0, 0, 1, 0, o, 0, 0, // one entry: orientation
    0, 0, 0, 0, // no next IFD
  ]);
}

// --- JPEG --------------------------------------------------------------------
interface JpegSeg { marker: number; start: number; end: number } // end exclusive; entropy data is part of the SOS segment
function jpegSegments(b: Uint8Array): { segs: JpegSeg[]; width: number; height: number; orientation: number; end: number } {
  if (b.length < 4 || b[0] !== 0xff || b[1] !== 0xd8) throw new ProcessError("malformed");
  const segs: JpegSeg[] = [];
  let i = 2, width = 0, height = 0, orientation = 1, sawSos = false;
  for (;;) {
    while (i < b.length && b[i] === 0xff && b[i + 1] === 0xff) i++; // fill bytes
    if (i + 2 > b.length || b[i] !== 0xff) throw new ProcessError("malformed");
    const marker = b[i + 1];
    if (marker === 0xd9) { // EOI
      if (!sawSos || !width) throw new ProcessError("malformed");
      return { segs, width, height, orientation, end: i + 2 };
    }
    if (marker === 0x00 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd8)) throw new ProcessError("malformed");
    if (i + 4 > b.length) throw new ProcessError("malformed");
    const len = u16(b, i + 2);
    let end = i + 2 + len;
    if (len < 2 || end > b.length) throw new ProcessError("malformed");
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
      if (marker > 0xc2) throw new ProcessError("unsupported"); // lossless / arithmetic coding
      if (len < 8 || b[i + 4] !== 8) throw new ProcessError("malformed");
      if (width) throw new ProcessError("malformed"); // second frame header
      height = u16(b, i + 5); width = u16(b, i + 7);
      const comps = b[i + 9];
      if (comps !== 1 && comps !== 3) throw new ProcessError("unsupported"); // CMYK etc.
    }
    if (marker === 0xe1 && b[i + 4] === 0x45 && ascii(b, i + 4, 4) === "Exif") orientation = tiffOrientation(b.subarray(i + 4, end));
    if (marker === 0xda) { // SOS: entropy-coded data follows until the next real marker
      if (!width) throw new ProcessError("malformed");
      sawSos = true;
      while (end < b.length && !(b[end] === 0xff && b[end + 1] !== 0x00 && !(b[end + 1] >= 0xd0 && b[end + 1] <= 0xd7))) end++;
      if (end + 1 >= b.length) throw new ProcessError("malformed"); // truncated: no EOI
    }
    segs.push({ marker, start: i, end });
    i = end;
  }
}

function walkJpeg(b: Uint8Array) {
  const { width, height, orientation } = jpegSegments(b);
  return { width, height, orientation };
}

function stripJpeg(b: Uint8Array): Uint8Array {
  const { segs, orientation } = jpegSegments(b);
  const parts: Uint8Array[] = [Uint8Array.of(0xff, 0xd8)];
  if (orientation !== 1) parts.push(orientationExif(orientation));
  for (const s of segs) {
    if ((s.marker >= 0xe0 && s.marker <= 0xef) || s.marker === 0xfe) continue; // APPn, COM
    parts.push(b.subarray(s.start, s.end));
  }
  parts.push(Uint8Array.of(0xff, 0xd9));
  return concat(parts);
}

// --- PNG ---------------------------------------------------------------------
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
})();
const crc32 = (b: Uint8Array) => { let c = 0xffffffff; for (const v of b) c = CRC_TABLE[(c ^ v) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const PNG_KEEP = new Set(["IHDR", "PLTE", "IDAT", "IEND", "tRNS", "gAMA", "cHRM", "sRGB"]);

function pngChunks(b: Uint8Array) {
  const chunks: { type: string; start: number; end: number }[] = [];
  let i = 8, width = 0, height = 0, orientation = 1, idat = false, plte = false, colorType = -1;
  for (;;) {
    if (i + 12 > b.length) throw new ProcessError("malformed");
    const len = u32(b, i), type = ascii(b, i + 4, 4), end = i + 12 + len;
    if (len > 0x7fffffff || end > b.length) throw new ProcessError("malformed");
    if (u32(b, end - 4) !== crc32(b.subarray(i + 4, end - 4))) throw new ProcessError("malformed");
    if (chunks.length === 0 && type !== "IHDR") throw new ProcessError("malformed");
    if (type === "IHDR") {
      if (chunks.length || len !== 13) throw new ProcessError("malformed");
      width = u32(b, i + 8); height = u32(b, i + 12); colorType = b[i + 17];
      const depth = b[i + 16];
      const ok: Record<number, number[]> = { 0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8], 4: [8, 16], 6: [8, 16] };
      if (!ok[colorType]?.includes(depth) || b[i + 18] !== 0 || b[i + 19] !== 0 || b[i + 20] > 1) throw new ProcessError("malformed");
    }
    if (type === "PLTE") plte = true;
    if (type === "IDAT") idat = true;
    if (type === "eXIf") orientation = tiffOrientation(b.subarray(i + 8, end - 4));
    chunks.push({ type, start: i, end });
    i = end;
    if (type === "IEND") break;
  }
  if (!idat || (colorType === 3 && !plte)) throw new ProcessError("malformed");
  return { chunks, width, height, orientation };
}

function walkPng(b: Uint8Array) {
  const { width, height, orientation } = pngChunks(b);
  return { width, height, orientation };
}

function stripPng(b: Uint8Array): Uint8Array {
  const { chunks } = pngChunks(b);
  return concat([Uint8Array.from(PNG_SIG), ...chunks.filter((c) => PNG_KEEP.has(c.type)).map((c) => b.subarray(c.start, c.end))]);
}

// --- WebP --------------------------------------------------------------------
function webpChunks(b: Uint8Array) {
  if (le32(b, 4) + 8 !== b.length) throw new ProcessError("malformed");
  const chunks: { type: string; start: number; end: number; dataStart: number; size: number }[] = [];
  let i = 12, width = 0, height = 0, orientation = 1, image = false;
  while (i < b.length) {
    if (i + 8 > b.length) throw new ProcessError("malformed");
    const type = ascii(b, i, 4), size = le32(b, i + 4), dataStart = i + 8, end = dataStart + size + (size & 1);
    if (end > b.length) throw new ProcessError("malformed");
    if (type === "VP8X") {
      if (size < 10) throw new ProcessError("malformed");
      if (b[dataStart] & 0x02) throw new ProcessError("unsupported"); // animation
      width = 1 + (b[dataStart + 4] | (b[dataStart + 5] << 8) | (b[dataStart + 6] << 16));
      height = 1 + (b[dataStart + 7] | (b[dataStart + 8] << 8) | (b[dataStart + 9] << 16));
    } else if (type === "VP8 ") {
      if (size < 10 || b[dataStart + 3] !== 0x9d || b[dataStart + 4] !== 0x01 || b[dataStart + 5] !== 0x2a) throw new ProcessError("malformed");
      width = (b[dataStart + 6] | (b[dataStart + 7] << 8)) & 0x3fff; height = (b[dataStart + 8] | (b[dataStart + 9] << 8)) & 0x3fff;
      image = true;
    } else if (type === "VP8L") {
      if (size < 5 || b[dataStart] !== 0x2f) throw new ProcessError("malformed");
      const v = le32(b, dataStart + 1);
      width = 1 + (v & 0x3fff); height = 1 + ((v >>> 14) & 0x3fff);
      image = true;
    } else if (type === "EXIF") orientation = tiffOrientation(b.subarray(dataStart, dataStart + size));
    chunks.push({ type, start: i, end, dataStart, size });
    i = end;
  }
  if (!image) throw new ProcessError("malformed");
  return { chunks, width, height, orientation };
}

function walkWebp(b: Uint8Array) {
  const { width, height, orientation } = webpChunks(b);
  return { width, height, orientation };
}

function stripWebp(b: Uint8Array): Uint8Array {
  const { chunks } = webpChunks(b);
  const kept = chunks.filter((c) => ["VP8X", "VP8 ", "VP8L", "ALPH"].includes(c.type)).map((c) => {
    const bytes = b.slice(c.start, c.end);
    if (c.type === "VP8X") bytes[8] &= ~(0x20 | 0x08 | 0x04); // no ICC, EXIF or XMP flags
    return bytes;
  });
  const body = concat(kept);
  const head = new Uint8Array(12);
  head.set(b.subarray(0, 4)); head.set(b.subarray(8, 12), 8);
  new DataView(head.buffer).setUint32(4, 4 + body.length, true);
  return concat([head, body]);
}
