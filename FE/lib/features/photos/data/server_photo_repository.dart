import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import 'models/body_photo.dart';
import 'photo_repository.dart';

class ServerPhotoRepository implements PhotoRepository {
  ServerPhotoRepository(this.api);
  final ApiClient api;
  String _filtered(BodyPhotoType type) {
    if (type == BodyPhotoType.unknown) {
      throw ArgumentError('Unknown photo type');
    }
    return Uri(
      path: ApiContract.photos,
      queryParameters: {'type': type.name, 'page': '1', 'page_size': '20'},
    ).toString();
  }

  @override
  Future<PhotoPage> list({BodyPhotoType type = BodyPhotoType.current}) async =>
      PhotoPage.fromJson((await api.send('GET', _filtered(type)))!);
  @override
  Future<BodyPhoto> upload(
    Uint8List jpeg, {
    required BodyPhotoType type,
    required BodyPhotoSide side,
  }) async {
    if (type == BodyPhotoType.unknown || side == BodyPhotoSide.unknown) {
      throw ArgumentError('Unknown photo type/side');
    }
    if (jpeg.isEmpty || jpeg.length > ApiContract.maxPhotoBytes) {
      throw StateError('10MB 이하의 사진을 선택해 주세요.');
    }
    final json = await api.upload(
      ApiContract.photos,
      files: [
        http.MultipartFile.fromBytes(
          'image',
          jpeg,
          filename: 'body.jpg',
          contentType: http.MediaType('image', 'jpeg'),
        ),
      ],
      fields: {'type': type.name, 'side': side.name},
    );
    return BodyPhoto.fromJson(json!);
  }

  @override
  Future<void> delete(int id) async {
    await api.send('DELETE', ApiContract.photo(id));
  }

  @override
  Future<PhotoDeleteResult> deleteAll({
    BodyPhotoType type = BodyPhotoType.current,
  }) async {
    if (type == BodyPhotoType.unknown) {
      throw ArgumentError('Unknown photo type');
    }
    final path = Uri(
      path: ApiContract.photos,
      queryParameters: {'type': type.name},
    ).toString();
    final json = (await api.send('DELETE', path))!;
    return PhotoDeleteResult(
      deleted: json['deleted_count'] as int,
      skipped: json['skipped_count'] as int,
    );
  }
}
