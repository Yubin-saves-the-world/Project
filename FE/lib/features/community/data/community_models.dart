import 'dart:typed_data';

const communityCategories = <String, String>{
  'info': '운동 정보',
  'proof': '인증',
  'question': '질문',
};

class CommunityAuthor {
  const CommunityAuthor(this.id, this.name);
  final int id;
  final String name;
  factory CommunityAuthor.fromJson(Map<String, dynamic> j) =>
      CommunityAuthor(j['user_id'] as int, j['nickname'] as String);
}

class CommunityImage {
  const CommunityImage(this.id, this.url, {this.bytes});
  final int id;
  final String url;
  final Uint8List? bytes;
  factory CommunityImage.fromJson(Map<String, dynamic> j) => CommunityImage(
    j['image_id'] as int,
    j['url'] as String,
    bytes: j['_bytes'] as Uint8List?,
  );
}

/// 목록 응답과 상세 응답을 함께 표현한다. 상세 전용 값은 목록에서 사용하지 않는다.
class CommunityPost {
  CommunityPost(Map<String, dynamic> json)
    : _json = Map.unmodifiable(json),
      id = json['post_id'] as int,
      category = json['category'] as String,
      title = json['title'] as String,
      preview = json['content_preview'] as String,
      content = json['content'] as String? ?? '',
      author = CommunityAuthor.fromJson(
        Map<String, dynamic>.from(json['author'] as Map),
      ),
      thumbnail = json['thumbnail_url'] as String?,
      likes = json['like_count'] as int,
      comments = json['comment_count'] as int,
      views = json['view_count'] as int,
      pinned = json['is_pinned'] as bool,
      created = DateTime.parse(json['created_at'] as String).toLocal(),
      mine = json['is_mine'] as bool? ?? false,
      liked = json['liked_by_me'] as bool? ?? false,
      images = List.unmodifiable([
        for (final j in json['images'] as List? ?? const [])
          CommunityImage.fromJson(Map<String, dynamic>.from(j as Map)),
      ]);
  final Map<String, dynamic> _json;
  final int id, likes, comments, views;
  final String category, title, preview, content;
  final CommunityAuthor author;
  final String? thumbnail;
  final bool pinned, mine, liked;
  final DateTime created;
  final List<CommunityImage> images;
  CommunityPost withLike(Map<String, dynamic> like) => CommunityPost({
    ..._json,
    'like_count': like['like_count'],
    'liked_by_me': like['liked_by_me'],
  });
}

class CommunityComment {
  CommunityComment(Map<String, dynamic> json)
    : id = json['comment_id'] as int,
      parentId = json['parent_id'] as int?,
      author = CommunityAuthor.fromJson(
        Map<String, dynamic>.from(json['author'] as Map),
      ),
      content = json['content'] as String,
      deleted = json['is_deleted'] as bool,
      mine = json['is_mine'] as bool;
  final int id;
  final int? parentId;
  final CommunityAuthor author;
  final String content;
  final bool deleted, mine;
}

class BlockedMember {
  const BlockedMember(this.id, this.name);
  final int id;
  final String name;
  factory BlockedMember.fromJson(Map<String, dynamic> j) =>
      BlockedMember(j['user_id'] as int, j['nickname'] as String);
}

class CommunityPageResult<T> {
  const CommunityPageResult(this.items, this.page, this.total);
  final List<T> items;
  final int page, total;
  factory CommunityPageResult.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) parse,
  ) => CommunityPageResult(
    [
      for (final v in j['items'] as List)
        parse(Map<String, dynamic>.from(v as Map)),
    ],
    j['page'] as int,
    j['total'] as int,
  );
}

class CommunityUpload {
  CommunityUpload(this.bytes, this.name) {
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError('사진 한 장은 10MB 이하여야 해요.');
    }
    if (mime == null) throw StateError('JPG 또는 PNG 사진만 추가할 수 있어요.');
  }
  final Uint8List bytes;
  final String name;
  String? get mime {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      return 'image/png';
    }
    return null;
  }
}

class CommunityDraft {
  const CommunityDraft({
    required this.category,
    required this.title,
    required this.content,
    this.images = const [],
    this.removeImageIds = const [],
  });
  final String category, title, content;
  final List<CommunityUpload> images;
  final List<int> removeImageIds;
  void validate({CommunityPost? original}) {
    if (!communityCategories.containsKey(category) &&
        !(original?.category == 'notice' && category == 'notice')) {
      throw StateError('카테고리를 선택해 주세요.');
    }
    if (title.trim().isEmpty || title.trim().runes.length > 50) {
      throw StateError('제목은 1~50자로 입력해 주세요.');
    }
    if (content.trim().isEmpty || content.trim().runes.length > 2000) {
      throw StateError('내용은 1~2,000자로 입력해 주세요.');
    }
    final retained =
        original?.images.where((i) => !removeImageIds.contains(i.id)).length ??
        0;
    if (retained + images.length > 4) {
      throw StateError('사진은 최대 4장까지 추가할 수 있어요.');
    }
  }
}
