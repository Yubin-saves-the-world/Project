import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// compute로 실행할 수 있는 순수 사진 변환 함수.
Uint8List? preprocessBodyPhoto(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final resized = oriented.width > 1024 || oriented.height > 1024
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1024 : null,
          height: oriented.height > oriented.width ? 1024 : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
}
