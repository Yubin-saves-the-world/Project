import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import 'community_models.dart';

abstract interface class CommunityRepository {
  Future<CommunityPageResult<CommunityPost>> posts({
    String? category,
    int page = 1,
  });
  Future<CommunityPost> post(int id);
  Future<CommunityPost> save(CommunityDraft draft, {CommunityPost? original});
  Future<void> deletePost(int id);
  Future<Map<String, dynamic>> like(int id, bool value);
  Future<CommunityPageResult<CommunityComment>> comments(
    int id, {
    int page = 1,
  });
  Future<void> comment(int id, String content, {int? parentId});
  Future<void> deleteComment(int postId, int commentId);
  Future<void> report(String type, int id, String reason, String detail);
  Future<CommunityPageResult<BlockedMember>> blocks({int page = 1});
  Future<void> block(int userId);
  Future<void> unblock(int userId);
}

class ServerCommunityRepository implements CommunityRepository {
  ServerCommunityRepository(this.api);
  final ApiClient api;
  Map<String, dynamic> requiredJson(Map<String, dynamic>? j) =>
      j ?? (throw StateError('서버 응답이 비어 있어요. 다시 확인해 주세요.'));
  CommunityPost _detail(Map<String, dynamic>? response) {
    final json = requiredJson(response);
    if (json['content'] is! String ||
        json['images'] is! List ||
        json['is_mine'] is! bool ||
        json['liked_by_me'] is! bool) {
      throw const FormatException('Invalid post detail');
    }
    return CommunityPost(json);
  }

  @override
  Future<CommunityPageResult<CommunityPost>> posts({
    String? category,
    int page = 1,
  }) async => CommunityPageResult.fromJson(
    requiredJson(
      await api.send(
        'GET',
        '${ApiContract.posts}?${Uri(queryParameters: {'page': '$page', 'page_size': '20', 'category': ?category}).query}',
      ),
    ),
    CommunityPost.new,
  );
  @override
  Future<CommunityPost> post(int id) async =>
      _detail(await api.send('GET', ApiContract.post(id)));
  @override
  Future<CommunityPost> save(
    CommunityDraft draft, {
    CommunityPost? original,
  }) async {
    draft.validate(original: original);
    if (original != null && !original.mine) throw StateError('내 글만 수정할 수 있어요.');
    return _detail(
      await api.upload(
        original == null ? ApiContract.posts : ApiContract.post(original.id),
        method: original == null ? 'POST' : 'PATCH',
        fields: {
          'category': draft.category,
          'title': draft.title.trim(),
          'content': draft.content.trim(),
        },
        repeatedFields: {
          'remove_image_ids': [for (final id in draft.removeImageIds) '$id'],
        },
        files: [
          for (final image in draft.images)
            http.MultipartFile.fromBytes(
              'images',
              image.bytes,
              filename: image.mime == 'image/png' ? 'photo.png' : 'photo.jpg',
              contentType: http.MediaType.parse(image.mime!),
            ),
        ],
      ),
    );
  }

  @override
  Future<void> deletePost(int id) async {
    await api.send('DELETE', ApiContract.post(id));
  }

  @override
  Future<Map<String, dynamic>> like(int id, bool value) async => requiredJson(
    await api.send(value ? 'POST' : 'DELETE', ApiContract.postLikes(id)),
  );
  @override
  Future<CommunityPageResult<CommunityComment>> comments(
    int id, {
    int page = 1,
  }) async => CommunityPageResult.fromJson(
    requiredJson(
      await api.send(
        'GET',
        '${ApiContract.postComments(id)}?page=$page&page_size=20',
      ),
    ),
    CommunityComment.new,
  );
  @override
  Future<void> comment(int id, String content, {int? parentId}) async {
    if (content.trim().isEmpty || content.trim().runes.length > 500) {
      throw StateError('댓글은 1~500자로 입력해 주세요.');
    }
    await api.send(
      'POST',
      ApiContract.postComments(id),
      body: {'content': content.trim(), 'parent_id': ?parentId},
    );
  }

  @override
  Future<void> deleteComment(int postId, int commentId) async {
    await api.send('DELETE', ApiContract.postComment(postId, commentId));
  }

  @override
  Future<void> report(String type, int id, String reason, String detail) async {
    await api.send(
      'POST',
      ApiContract.reports,
      body: {
        'target_type': type,
        'target_id': id,
        'reason': reason,
        if (detail.trim().isNotEmpty) 'detail': detail.trim(),
      },
    );
  }

  @override
  Future<CommunityPageResult<BlockedMember>> blocks({int page = 1}) async =>
      CommunityPageResult.fromJson(
        requiredJson(
          await api.send(
            'GET',
            '${ApiContract.blocks}?page=$page&page_size=20',
          ),
        ),
        BlockedMember.fromJson,
      );
  @override
  Future<void> block(int userId) async {
    await api.send('POST', ApiContract.block(userId));
  }

  @override
  Future<void> unblock(int userId) async {
    await api.send('DELETE', ApiContract.block(userId));
  }
}

abstract interface class CommunityImagePicker {
  Future<List<CommunityUpload>> pick(int remaining);
}

class NativeCommunityImagePicker implements CommunityImagePicker {
  @override
  Future<List<CommunityUpload>> pick(int remaining) async {
    final selected = await ImagePicker().pickMultiImage(
      requestFullMetadata: false,
    );
    if (selected.length > remaining) throw StateError('사진은 최대 4장까지 추가할 수 있어요.');
    final result = <CommunityUpload>[];
    for (final image in selected) {
      if (await image.length() > ApiContract.maxPhotoBytes) {
        throw StateError('사진 한 장은 10MB 이하여야 해요.');
      }
      result.add(CommunityUpload(await image.readAsBytes(), image.name));
    }
    return result;
  }
}
