import 'dart:typed_data';

enum BodyPhotoType { current, goal, unknown }

enum BodyPhotoSide { front, side, back, unknown }

class BodyPhoto {
  const BodyPhoto({
    required this.id,
    required this.type,
    required this.side,
    required this.url,
    required this.urlExpiresAt,
    required this.createdAt,
    this.previewBytes,
  });
  final int id;
  final BodyPhotoType type;
  final BodyPhotoSide side;
  final String url;
  final DateTime urlExpiresAt, createdAt;
  final Uint8List? previewBytes;
  String get sideLabel => switch (side) {
    BodyPhotoSide.front => '정면',
    BodyPhotoSide.side => '측면',
    BodyPhotoSide.back => '후면',
    BodyPhotoSide.unknown => '사진',
  };
  factory BodyPhoto.fromJson(Map<String, dynamic> json) => BodyPhoto(
    id: json['photo_id'] as int,
    type: BodyPhotoType.values.firstWhere(
      (v) => v.name == json['type'],
      orElse: () => BodyPhotoType.unknown,
    ),
    side: BodyPhotoSide.values.firstWhere(
      (v) => v.name == json['side'],
      orElse: () => BodyPhotoSide.unknown,
    ),
    url: json['url'] as String,
    urlExpiresAt: DateTime.parse(json['url_expires_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class PhotoPage {
  PhotoPage(List<BodyPhoto> items, this.total)
    : items = List.unmodifiable(items);
  final List<BodyPhoto> items;
  final int total;
  factory PhotoPage.fromJson(Map<String, dynamic> json) => PhotoPage(
    (json['items'] as List)
        .map((v) => BodyPhoto.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList(),
    json['total'] as int,
  );
}

class PhotoDeleteResult {
  const PhotoDeleteResult({required this.deleted, required this.skipped});
  final int deleted, skipped;
}
