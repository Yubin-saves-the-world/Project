import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/photos/data/models/selected_photo.dart';
import 'image_preprocessor.dart';
import '../network/api_contract.dart';

abstract interface class PhotoPicker {
  Future<SelectedPhoto?> pick(PhotoSlot slot, PhotoSource source);
  Future<(PhotoSlot, SelectedPhoto)?> recover();
  Future<bool> exists(SelectedPhoto photo);
  Future<void> discard(SelectedPhoto photo);
}

class PhotoPickerException implements Exception {
  const PhotoPickerException(this.message);
  final String message;
}

class ImagePickerService implements PhotoPicker {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  final _preferences = SharedPreferencesAsync();
  static const _pendingSlotKey = 'vitality.onboarding.pending-photo-slot';

  @override
  Future<SelectedPhoto?> pick(PhotoSlot slot, PhotoSource source) async {
    await _preferences.setString(_pendingSlotKey, slot.name);
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      return await _prepare(file, slot);
    } on PlatformException catch (error) {
      throw PhotoPickerException(switch (error.code) {
        'camera_access_denied' ||
        'photo_access_denied' ||
        'camera_access_restricted' ||
        'photo_access_restricted' =>
          '카메라 또는 사진 접근이 허용되지 않았어요. 기기 설정에서 권한을 확인해 주세요.',
        _ => '사진을 가져오지 못했어요. 다시 선택해 주세요.',
      });
    } finally {
      await _preferences.remove(_pendingSlotKey);
    }
  }

  Future<SelectedPhoto> _prepare(XFile file, PhotoSlot slot) async {
    final bytes = await file.readAsBytes();
    final isJpeg = bytes.length > 2 && bytes[0] == 0xff && bytes[1] == 0xd8;
    final isPng =
        bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    if (!isJpeg && !isPng) {
      throw const PhotoPickerException('JPG 또는 PNG 사진을 선택해 주세요.');
    }
    final processed = await compute(preprocessBodyPhoto, bytes);
    if (processed == null) {
      throw const PhotoPickerException('읽을 수 없는 사진이에요. 다른 사진을 선택해 주세요.');
    }
    if (processed.length > ApiContract.maxPhotoBytes) {
      throw const PhotoPickerException(
        '사진을 줄인 뒤에도 10MB를 초과해요. 다른 사진을 선택해 주세요.',
      );
    }
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/onboarding_photos',
    );
    await directory.create(recursive: true);
    final destination = File(
      '${directory.path}/${slot.name}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await destination.writeAsBytes(processed, flush: true);
    return SelectedPhoto(path: destination.path, byteLength: processed.length);
  }

  @override
  Future<(PhotoSlot, SelectedPhoto)?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final pending = await _preferences.getString(_pendingSlotKey);
    final data = await _picker.retrieveLostData();
    try {
      if (data.exception != null) {
        throw const PhotoPickerException('이전 사진 선택을 복원하지 못했어요. 다시 선택해 주세요.');
      }
      if (data.files == null || data.files!.isEmpty) return null;
      final slot = PhotoSlot.values.firstWhere(
        (value) => value.name == pending,
        orElse: () => PhotoSlot.front,
      );
      return (slot, await _prepare(data.files!.first, slot));
    } finally {
      await _preferences.remove(_pendingSlotKey);
    }
  }

  @override
  Future<bool> exists(SelectedPhoto photo) => File(photo.path).exists();

  @override
  Future<void> discard(SelectedPhoto photo) async {
    final directory =
        '${(await getApplicationSupportDirectory()).path}/onboarding_photos/';
    // 선택기의 원본 파일은 지우지 않고 앱이 만든 사본만 정리한다.
    if (!photo.path.startsWith(directory)) return;
    final file = File(photo.path);
    if (await file.exists()) await file.delete();
  }
}
