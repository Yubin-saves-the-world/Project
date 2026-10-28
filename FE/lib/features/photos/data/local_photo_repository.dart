import 'dart:typed_data';
import '../../../core/network/api_contract.dart';
import 'models/body_photo.dart';
import 'photo_repository.dart';

/// 로컬 미리보기의 세션 내 사진 목록. 서버 사진 저장소와 섞지 않는다.
class LocalPhotoRepository implements PhotoRepository {
  final List<BodyPhoto> _items = [];
  int _next = 1;
  @override
  Future<PhotoPage> list({BodyPhotoType type = BodyPhotoType.current}) async {
    final items = _items.where((v) => v.type == type).toList();
    return PhotoPage(items, items.length);
  }

  @override
  Future<BodyPhoto> upload(
    Uint8List jpeg, {
    required BodyPhotoType type,
    required BodyPhotoSide side,
  }) async {
    if (_items.length >= ApiContract.photoLimit) {
      throw StateError('사진은 최대 20장까지 올릴 수 있어요. 기존 사진을 삭제해 주세요.');
    }
    final now = DateTime.now();
    final photo = BodyPhoto(
      id: _next++,
      type: type,
      side: side,
      url: '',
      urlExpiresAt: now.add(const Duration(days: 365)),
      createdAt: now,
      previewBytes: Uint8List.fromList(jpeg),
    );
    _items.insert(0, photo);
    return photo;
  }

  @override
  Future<void> delete(int id) async {
    _items.removeWhere((v) => v.id == id);
  }

  @override
  Future<PhotoDeleteResult> deleteAll({
    BodyPhotoType type = BodyPhotoType.current,
  }) async {
    final count = _items.where((v) => v.type == type).length;
    _items.removeWhere((v) => v.type == type);
    return PhotoDeleteResult(deleted: count, skipped: 0);
  }
}
