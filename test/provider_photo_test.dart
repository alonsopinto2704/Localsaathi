import 'package:flutter_test/flutter_test.dart';
import 'package:localsaathi/domain/models/provider.dart';

void main() {
  test('a picked photo survives the profile JSON round trip', () {
    final ProviderPhoto photo = ProviderPhoto(
      id: 'p1',
      caption: 'Bathroom fitting',
      imageBase64: 'aGVsbG8=',
      uploadedAt: DateTime(2026, 10, 4, 12),
    );

    final ProviderPhoto back = ProviderPhoto.fromJson(photo.toJson());

    expect(back.imageBase64, 'aGVsbG8=');
    expect(back.caption, 'Bathroom fitting');
    expect(back.uploadedAt, DateTime(2026, 10, 4, 12));
    expect(back.hasImage, isTrue);
  });

  test('a placeholder without an image stays imageless', () {
    final ProviderPhoto back = ProviderPhoto.fromJson(
      const ProviderPhoto(id: 'p2', caption: 'x', isPlaceholder: true).toJson(),
    );
    expect(back.hasImage, isFalse);
    expect(back.isPlaceholder, isTrue);
  });
}
