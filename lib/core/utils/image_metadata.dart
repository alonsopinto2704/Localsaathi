import 'dart:typed_data';

/// Removes location and device metadata from a photo before it is stored or
/// published.
///
/// Phone photos carry EXIF GPS coordinates, camera serial numbers and owner
/// names, and the Android image picker copies them into resized images. A
/// provider's "work photo" taken at home would publish their address.
///
/// * JPEG: drops every APPn segment (EXIF, XMP, IPTC, maker notes) and
///   comments, then adds back a minimal EXIF block holding only the
///   orientation, so portrait photos still display upright.
/// * PNG: drops text, timestamp and eXIf chunks.
///
/// Returns null for anything else, or for a malformed file, so the caller can
/// refuse it instead of publishing something it could not clean.
Uint8List? stripImageMetadata(Uint8List bytes) {
  if (bytes.length > 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return _stripJpeg(bytes);
  }
  if (bytes.length > 8 && _startsWith(bytes, _pngSignature)) {
    return _stripPng(bytes);
  }
  return null;
}

const List<int> _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

bool _startsWith(Uint8List b, List<int> prefix) {
  for (int i = 0; i < prefix.length; i++) {
    if (b[i] != prefix[i]) return false;
  }
  return true;
}

Uint8List? _stripJpeg(Uint8List b) {
  final List<(int, int)> keep = <(int, int)>[];
  int orientation = 1;
  int i = 2;
  while (true) {
    if (i + 4 > b.length || b[i] != 0xFF) return null;
    final int marker = b[i + 1];
    if (marker == 0xFF) {
      i++; // fill byte
      continue;
    }
    if (marker == 0xDA) {
      // Start of scan: the compressed image follows. Copy it untouched.
      keep.add((i, b.length));
      break;
    }
    final int end = i + 2 + ((b[i + 2] << 8) | b[i + 3]);
    if (end > b.length || end < i + 4) return null;
    if (marker == 0xE1) {
      orientation = _exifOrientation(b, i + 4, end) ?? orientation;
    }
    final bool metadata = (marker >= 0xE0 && marker <= 0xEF) || marker == 0xFE;
    if (!metadata) keep.add((i, end));
    i = end;
  }

  final BytesBuilder out = BytesBuilder(copy: false)..add(const <int>[0xFF, 0xD8]);
  if (orientation != 1) out.add(_orientationOnlyExif(orientation));
  for (final (int start, int end) in keep) {
    out.add(Uint8List.sublistView(b, start, end));
  }
  return out.takeBytes();
}

/// Reads tag 0x0112 from IFD0 of an APP1 "Exif" payload in [start, end).
int? _exifOrientation(Uint8List b, int start, int end) {
  const List<int> exifHeader = <int>[0x45, 0x78, 0x69, 0x66, 0, 0];
  if (end - start < 14) return null;
  for (int k = 0; k < exifHeader.length; k++) {
    if (b[start + k] != exifHeader[k]) return null;
  }
  final int tiff = start + 6;
  final bool little = b[tiff] == 0x49 && b[tiff + 1] == 0x49;
  final bool big = b[tiff] == 0x4D && b[tiff + 1] == 0x4D;
  if (!little && !big) return null;

  int u16(int at) =>
      little ? b[at] | (b[at + 1] << 8) : (b[at] << 8) | b[at + 1];
  int u32(int at) => little
      ? b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24)
      : (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

  final int ifd0 = tiff + u32(tiff + 4);
  if (ifd0 + 2 > end) return null;
  final int count = u16(ifd0);
  for (int k = 0; k < count; k++) {
    final int entry = ifd0 + 2 + 12 * k;
    if (entry + 12 > end) return null;
    if (u16(entry) == 0x0112) {
      final int value = u16(entry + 8);
      return value >= 1 && value <= 8 ? value : null;
    }
  }
  return null;
}

/// A 36-byte APP1 segment: big-endian TIFF with one IFD0 entry, Orientation.
Uint8List _orientationOnlyExif(int orientation) => Uint8List.fromList(<int>[
      0xFF, 0xE1, 0x00, 0x22, // APP1, length 34
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif\0\0"
      0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // "MM", 42, IFD0 at 8
      0x00, 0x01, // one entry
      0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, // Orientation, SHORT, 1
      0x00, orientation, 0x00, 0x00, // value
      0x00, 0x00, 0x00, 0x00, // no next IFD
    ]);

Uint8List? _stripPng(Uint8List b) {
  const Set<String> drop = <String>{'tEXt', 'zTXt', 'iTXt', 'eXIf', 'tIME'};
  final BytesBuilder out = BytesBuilder(copy: false)..add(_pngSignature);
  int i = 8;
  while (i + 12 <= b.length) {
    final int length =
        (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
    final int end = i + 12 + length;
    if (length < 0 || end > b.length) return null;
    final String type = String.fromCharCodes(b, i + 4, i + 8);
    if (!drop.contains(type)) out.add(Uint8List.sublistView(b, i, end));
    i = end;
    if (type == 'IEND') return out.takeBytes();
  }
  return null; // no IEND: truncated
}
