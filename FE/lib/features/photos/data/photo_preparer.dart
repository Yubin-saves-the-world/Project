import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/media/image_preprocessor.dart';
import '../../../core/network/api_contract.dart';
import 'models/selected_photo.dart';

abstract interface class PhotoPreparer {
  Future<Uint8List> prepare(SelectedPhoto photo);
}

class FilePhotoPreparer implements PhotoPreparer {
  @override
  Future<Uint8List> prepare(SelectedPhoto photo) async {
    final bytes = await File(photo.path).readAsBytes();
    final jpeg = bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8;
    final png =
        bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    if (!jpeg && !png) {
      throw const PhotoPickerException('JPG 또는 PNG 사진을 선택해 주세요.');
    }
    final processed = await compute(preprocessBodyPhoto, bytes);
    if (processed == null) {
      throw const PhotoPickerException('읽을 수 없는 사진이에요. 다른 사진을 선택해 주세요.');
    }
    if (processed.length > ApiContract.maxPhotoBytes) {
      throw const PhotoPickerException('사진이 10MB를 초과해요. 다른 사진을 선택해 주세요.');
    }
    return processed;
  }
}
