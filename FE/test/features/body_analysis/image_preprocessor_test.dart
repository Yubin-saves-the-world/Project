import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fe/core/media/image_preprocessor.dart';

void main() {
  test('세로·가로 사진 모두 긴 변을1024px로 줄이고 JPEG로 변환한다', () {
    for (final size in [(2048, 1024), (1024, 2048)]) {
      final input = img.Image(width: size.$1, height: size.$2);
      final output = preprocessBodyPhoto(
        Uint8List.fromList(img.encodePng(input)),
      )!;
      final result = img.decodeJpg(output)!;
      expect([result.width, result.height], contains(1024));
      expect(result.width <= 1024 && result.height <= 1024, isTrue);
      expect(result.width / result.height, closeTo(size.$1 / size.$2, .01));
    }
  });
  test('작은 사진을 확대하지 않고 손상된 사진은 결과를 만들지 않는다', () {
    final input = img.Image(width: 64, height: 32);
    final output = preprocessBodyPhoto(
      Uint8List.fromList(img.encodePng(input)),
    )!;
    final result = img.decodeJpg(output)!;
    expect((result.width, result.height), (64, 32));
    expect(preprocessBodyPhoto(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
