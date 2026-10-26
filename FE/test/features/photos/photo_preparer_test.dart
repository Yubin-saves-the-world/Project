import 'dart:io';
import 'package:fe/features/photos/data/photo_preparer.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/core/media/image_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('업로드 파일의 EXIF 회전을 반영하고 긴 변 1024 이하 JPEG로 변환한다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'movid-photo-preparer-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final original = img.Image(width: 2048, height: 1024);
    original.exif.imageIfd.orientation = 6;
    final file = File('${directory.path}/rotated.jpg');
    await file.writeAsBytes(img.encodeJpg(original));
    final result = img.decodeJpg(
      await FilePhotoPreparer().prepare(
        SelectedPhoto(path: file.path, byteLength: await file.length()),
      ),
    )!;
    expect((result.width, result.height), (512, 1024));
  });
  test('확장자가 JPG여도 실제 파일 내용이 이미지가 아니면 거부한다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'movid-photo-invalid-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fake.jpg');
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(
      FilePhotoPreparer().prepare(
        SelectedPhoto(path: file.path, byteLength: 3),
      ),
      throwsA(isA<PhotoPickerException>()),
    );
  });
}
