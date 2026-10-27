import 'dart:math' as math;
import 'community_models.dart';
import 'community_repository.dart';

/// 명시적으로 로컬 미리보기를 선택했을 때만 사용한다. 실제 게시/신고/차단이 아니다.
/// 계정별 인스턴스이며 앱을 종료하면 초기화된다. 기존 기기 저장 형식은 변경하지 않는다.
class LocalCommunityRepository implements CommunityRepository {
  LocalCommunityRepository(this.nickname) {
    final examples = [
      (
        'notice',
        '커뮤니티 이용 안내',
        '운동 경험을 나누고 서로 존중해 주세요. 이 글은 미리보기 예시입니다.',
        '운영팀',
      ),
      (
        'info',
        '꾸준히 운동한 3개월의 기록',
        '처음보다 운동 자세가 편해졌어요. 매주 기록한 내용을 정리해 봤습니다.',
        '유빈',
      ),
      ('proof', '스쿼트 60kg 넘겼습니다', '두 달 전에 40kg도 무거웠는데 루틴대로 하니까 되네요.', '예준'),
    ];
    for (var i = 0; i < examples.length; i++) {
      final e = examples[i];
      _posts[i + 1] = {
        'post_id': i + 1,
        'category': e.$1,
        'title': e.$2,
        'content': e.$3,
        'content_preview': e.$3,
        'author': {'user_id': i + 2, 'nickname': e.$4},
        'thumbnail_url': null,
        'like_count': 0,
        'comment_count': 0,
        'view_count': 0,
        'is_pinned': i == 0,
        'created_at': DateTime.now()
            .subtract(Duration(hours: i))
            .toIso8601String(),
        'images': <Map<String, dynamic>>[],
        'liked_by_me': false,
        'is_mine': false,
        'updated_at': null,
      };
    }
  }
  final String Function() nickname;
  final _posts = <int, Map<String, dynamic>>{};
  final _comments = <int, List<Map<String, dynamic>>>{};
  final _blocks = <int, String>{};
  final _reports = <String>{};
  int _next = 100;
  Map<String, dynamic> _find(int id) =>
      _posts[id] ?? (throw StateError('글을 찾을 수 없어요.'));
  CommunityPageResult<T> _page<T>(List<T> items, int page) =>
      CommunityPageResult(
        items.skip((page - 1) * 20).take(20).toList(),
        page,
        items.length,
      );
  @override
  Future<CommunityPageResult<CommunityPost>> posts({
    String? category,
    int page = 1,
  }) async {
    final items =
        _posts.values
            .where(
              (j) =>
                  !_blocks.containsKey((j['author'] as Map)['user_id']) &&
                  (category == null || j['category'] == category),
            )
            .toList()
          ..sort((a, b) {
            if (a['is_pinned'] != b['is_pinned']) {
              return a['is_pinned'] == true ? -1 : 1;
            }
            return (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            );
          });
    return _page(items.map(CommunityPost.new).toList(), page);
  }

  @override
  Future<CommunityPost> post(int id) async {
    final j = _find(id);
    if (_blocks.containsKey((j['author'] as Map)['user_id'])) {
      throw StateError('차단한 사용자의 글이에요.');
    }
    j['view_count'] = (j['view_count'] as int) + 1;
    return CommunityPost(j);
  }

  @override
  Future<CommunityPost> save(
    CommunityDraft draft, {
    CommunityPost? original,
  }) async {
    draft.validate(original: original);
    if (original != null && !original.mine) throw StateError('내 글만 수정할 수 있어요.');
    final id = original?.id ?? _next++;
    final old = original == null ? null : _find(id);
    final images = <Map<String, dynamic>>[
      if (old != null)
        for (final i in old['images'] as List)
          if (!draft.removeImageIds.contains((i as Map)['image_id']))
            Map<String, dynamic>.from(i),
      for (final i in draft.images)
        {'image_id': _next++, 'url': '', '_bytes': i.bytes},
    ];
    final j = <String, dynamic>{
      if (old != null) ...old,
      'post_id': id,
      'category': draft.category,
      'title': draft.title.trim(),
      'content': draft.content.trim(),
      'content_preview': draft.content.trim(),
      'images': images,
      'author': {'user_id': 1, 'nickname': nickname()},
      'thumbnail_url': null,
      'like_count': old?['like_count'] ?? 0,
      'comment_count': old?['comment_count'] ?? 0,
      'view_count': old?['view_count'] ?? 0,
      'is_pinned': false,
      'created_at': old?['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': old == null ? null : DateTime.now().toIso8601String(),
      'liked_by_me': old?['liked_by_me'] ?? false,
      'is_mine': true,
    };
    _posts[id] = j;
    return CommunityPost(j);
  }

  @override
  Future<void> deletePost(int id) async {
    if (_find(id)['is_mine'] != true) throw StateError('내 글만 삭제할 수 있어요.');
    _posts.remove(id);
    _comments.remove(id);
  }

  @override
  Future<Map<String, dynamic>> like(int id, bool value) async {
    final j = _find(id);
    if (j['liked_by_me'] != value) {
      j['like_count'] = (j['like_count'] as int) + (value ? 1 : -1);
    }
    j['liked_by_me'] = value;
    return {'post_id': id, 'like_count': j['like_count'], 'liked_by_me': value};
  }

  @override
  Future<CommunityPageResult<CommunityComment>> comments(
    int id, {
    int page = 1,
  }) async {
    _find(id);
    final visible = (_comments[id] ?? [])
        .where((j) => !_blocks.containsKey((j['author'] as Map)['user_id']))
        .toList();
    final ordered = <Map<String, dynamic>>[];
    for (final j in visible.where((j) => j['parent_id'] == null)) {
      ordered.add(j);
      ordered.addAll(visible.where((r) => r['parent_id'] == j['comment_id']));
    }
    return _page(ordered.map(CommunityComment.new).toList(), page);
  }

  @override
  Future<void> comment(int id, String content, {int? parentId}) async {
    final j = _find(id);
    if (content.trim().isEmpty || content.trim().runes.length > 500) {
      throw StateError('댓글은 1~500자로 입력해 주세요.');
    }
    if (parentId != null &&
        !(_comments[id] ?? []).any(
          (c) => c['comment_id'] == parentId && c['parent_id'] == null,
        )) {
      throw StateError('답글을 달 댓글을 찾을 수 없어요.');
    }
    (_comments[id] ??= []).add({
      'comment_id': _next++,
      'post_id': id,
      'parent_id': parentId,
      'author': {'user_id': 1, 'nickname': nickname()},
      'content': content.trim(),
      'is_deleted': false,
      'is_mine': true,
      'created_at': DateTime.now().toIso8601String(),
    });
    j['comment_count'] = (j['comment_count'] as int) + 1;
  }

  @override
  Future<void> deleteComment(int postId, int commentId) async {
    final items = _comments[postId] ?? [];
    final j = items.firstWhere((c) => c['comment_id'] == commentId);
    if (j['is_mine'] != true) throw StateError('내 댓글만 삭제할 수 있어요.');
    if (j['is_deleted'] == true) return;
    if (items.any((c) => c['parent_id'] == commentId)) {
      j['is_deleted'] = true;
      j['content'] = '삭제된 댓글입니다.';
    } else {
      items.remove(j);
    }
    final p = _find(postId);
    p['comment_count'] = math.max(0, (p['comment_count'] as int) - 1);
  }

  @override
  Future<void> report(String type, int id, String reason, String detail) async {
    if (!_reports.add('$type:$id')) throw StateError('미리보기에서 이미 신고한 항목이에요.');
  }

  @override
  Future<CommunityPageResult<BlockedMember>> blocks({int page = 1}) async =>
      _page([
        for (final e in _blocks.entries) BlockedMember(e.key, e.value),
      ], page);
  @override
  Future<void> block(int userId) async {
    if (userId == 1) throw StateError('본인을 차단할 수 없어요.');
    final authors = [
      for (final j in _posts.values) j['author'] as Map,
      for (final cs in _comments.values)
        for (final j in cs) j['author'] as Map,
    ];
    _blocks[userId] =
        authors.firstWhere((a) => a['user_id'] == userId)['nickname'] as String;
  }

  @override
  Future<void> unblock(int userId) async {
    _blocks.remove(userId);
  }
}
