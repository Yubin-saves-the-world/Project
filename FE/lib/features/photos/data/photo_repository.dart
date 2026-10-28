import 'dart:typed_data';
import 'models/body_photo.dart';

abstract interface class PhotoRepository {
  Future<PhotoPage> list({BodyPhotoType type = BodyPhotoType.current});
  Future<BodyPhoto> upload(
    Uint8List jpeg, {
    required BodyPhotoType type,
    required BodyPhotoSide side,
  });
  Future<void> delete(int id);
  Future<PhotoDeleteResult> deleteAll({
    BodyPhotoType type = BodyPhotoType.current,
  });
}
