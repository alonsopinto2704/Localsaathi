import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/core/utils/image_metadata.dart';

// Real files made with Pillow. The JPEG carries EXIF Orientation=6, Make
// "SecretMake", Artist "RameshOwner", GPS 19°07'N 72°49'E and a comment
// "secret-comment"; the PNG carries a tEXt chunk "HomeAddress42".
final Uint8List _jpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/4QDERXhpZgAATU0AKgAAAAgABAEPAAIAAAALAAAAPgESAAMAAAABAAYAAAE7AAIAAAAMAAAASoglAAQAAAABAAAAVgAAAABTZWNyZXRNYWtlAABSYW1lc2hPd25lcgAABAABAAIAAAACTgAAAAACAAUAAAADAAAAjAADAAIAAAACRQAAAAAEAAUAAAADAAAApAAAAAAAAAATAAAAAQAAAAcAAAABAAAAPQAAAAIAAABIAAAAAQAAADEAAAABAAAAoQAAAAT//gAQc2VjcmV0LWNvbW1lbnT/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAACAAQDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDw+iiivoz+dz//2Q==',
);
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFnRFWHRMb2NhdGlvbgBIb21lQWRkcmVzczQyQCzEMgAAABJJREFUeJxjZGRiZmBgYGIAAwAAcAAKsgEgTQAAAABJRU5ErkJggg==',
);

bool _contains(Uint8List haystack, String needle) =>
    latin1.decode(haystack).contains(needle);

void main() {
  test('JPEG: location, device and owner metadata are removed', () {
    expect(_contains(_jpeg, 'RameshOwner'), isTrue, reason: 'fixture check');

    final Uint8List clean = stripImageMetadata(_jpeg)!;

    for (final String secret in <String>[
      'RameshOwner',
      'SecretMake',
      'secret-comment',
      'JFIF',
    ]) {
      expect(_contains(clean, secret), isFalse, reason: secret);
    }
    // Only our 36-byte EXIF block remains, carrying Orientation = 6.
    expect(clean.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(clean.sublist(2, 4), <int>[0xFF, 0xE1]);
    expect(clean[2 + 29], 6); // IFD0 entry at 20, its value at 28..29
    expect(clean.length, lessThan(_jpeg.length));
  });

  testWidgets('a cleaned JPEG still decodes', (WidgetTester tester) async {
    final Uint8List clean = stripImageMetadata(_jpeg)!;
    final ui.Codec? codec = await tester.runAsync(
      () => ui.instantiateImageCodec(clean),
    );
    expect(codec!.frameCount, 1);
  });

  test('PNG: text chunks are removed, image chunks kept', () {
    expect(_contains(_png, 'HomeAddress42'), isTrue, reason: 'fixture check');
    final Uint8List clean = stripImageMetadata(_png)!;
    expect(_contains(clean, 'HomeAddress42'), isFalse);
    expect(_contains(clean, 'IDAT'), isTrue);
    expect(_contains(clean, 'IEND'), isTrue);
  });

  test('unsupported or malformed files are refused, not published', () {
    expect(
      stripImageMetadata(Uint8List.fromList(utf8.encode('GIF89a...'))),
      isNull,
    );
    expect(stripImageMetadata(Uint8List.sublistView(_jpeg, 0, 40)), isNull);
    expect(stripImageMetadata(Uint8List.sublistView(_png, 0, 40)), isNull);
  });
}
