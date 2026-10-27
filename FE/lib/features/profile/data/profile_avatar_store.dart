import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' as native;
import 'package:shared_preferences/shared_preferences.dart';
import '../../photos/data/models/selected_photo.dart';

abstract interface class ProfileAvatarPicker {
  Future<Uint8List?> pick(PhotoSource source);
}

Uint8List? prepareProfileAvatar(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    return Uint8List.fromList(
      img.encodeJpg(
        img.copyResizeCropSquare(img.bakeOrientation(image), size: 256),
        quality: 85,
      ),
    );
  } catch (_) {
    return null;
  }
}

class NativeProfileAvatarPicker implements ProfileAvatarPicker {
  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    final file = await native.ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? native.ImageSource.camera
          : native.ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > 10 * 1024 * 1024) {
      throw StateError('10MB 이하의 사진을 선택해 주세요.');
    }
    final result = await compute(
      prepareProfileAvatar,
      await file.readAsBytes(),
    );
    if (result == null) {
      throw StateError('읽을 수 없는 사진이에요. JPG 또는 PNG 사진을 선택해 주세요.');
    }
    return result;
  }
}

class ProfileAvatarStore {
  ProfileAvatarStore(String owner, {SharedPreferencesAsync? preferences})
    : _preferences = preferences,
      key = keyFor(owner) {
    if (owner.trim().isEmpty) throw ArgumentError('프로필 소유자가 필요해요.');
  }
  static final _changes = StreamController<String>.broadcast(sync: true);
  static Stream<String> get changes => _changes.stream;
  final SharedPreferencesAsync? _preferences;
  late final SharedPreferencesAsync _prefs =
      _preferences ?? SharedPreferencesAsync();
  final String key;
  static String keyFor(String owner) =>
      'movid.profile.avatar.v1.${base64Url.encode(utf8.encode(owner.trim().toLowerCase()))}';
  Future<Uint8List?> load() async {
    final value = await _prefs.getString(key);
    if (value == null) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      throw StateError('프로필 사진을 불러오지 못했어요. 다시 선택해 주세요.');
    }
  }

  Future<void> save(Uint8List? bytes) async {
    if (bytes == null) {
      await _prefs.remove(key);
    } else {
      if (bytes.length > 512 * 1024) throw StateError('프로필 사진 크기를 줄여 주세요.');
      await _prefs.setString(key, base64Encode(bytes));
    }
    _changes.add(key);
  }
}
