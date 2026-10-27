import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/community/data/community_models.dart';
import 'package:fe/features/community/data/community_repository.dart';
import 'package:fe/features/community/data/local_community_repository.dart';
import 'package:fe/features/community/presentation/community_controller.dart';

Map<String, dynamic> sample({int id = 9, bool mine = true}) => {
  'post_id': id,
  'category': 'info',
  'title': '운동 기록',
  'content_preview': '내용',
  'content': '내용',
  'author': {'user_id': 1, 'nickname': '나'},
  'thumbnail_url': null,
  'like_count': 2,
  'comment_count': 0,
  'view_count': 3,
  'is_pinned': false,
  'created_at': '2026-10-27T12:00:00+09:00',
  'updated_at': null,
  'images': [
    for (final id in [10, 11])
      {'image_id': id, 'url': 'https://example.test/$id.jpg'},
  ],
  'liked_by_me': false,
  'is_mine': mine,
};
http.Response jsonResponse(Object json, [int status = 200]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(json)),
      status,
      headers: {'content-type': 'application/json'},
    );
CommunityDraft draft({
  List<CommunityUpload> images = const [],
  List<int> removed = const [],
}) => CommunityDraft(
  category: 'info',
  title: '제목',
  content: '내용',
  images: images,
  removeImageIds: removed,
);

class NoPicker implements CommunityImagePicker {
  @override
  Future<List<CommunityUpload>> pick(int remaining) async => [];
}

class PendingRepository extends LocalCommunityRepository {
  PendingRepository() : super(() => '나');
  final requests = <Completer<CommunityPageResult<CommunityPost>>>[];
  final categories = <String?>[];
  @override
  Future<CommunityPageResult<CommunityPost>> posts({
    String? category,
    int page = 1,
  }) {
    categories.add(category);
    final request = Completer<CommunityPageResult<CommunityPost>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  test('multipart PATCH는 반복 삭제 ID·여러 사진과 Bearer 인증을 보존한다', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('community-token');
    final calls = <String>[];
    final api = ApiClient(
      baseUrl: 'https://server.test',
      tokenStore: tokens,
      client: MockClient((r) async {
        expect(r.method, 'PATCH');
        expect(r.url.path, '/api/posts/9');
        expect(r.headers['Authorization'], 'Bearer community-token');
        expect(
          r.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        final body = latin1.decode(r.bodyBytes);
        expect(RegExp('name="remove_image_ids"').allMatches(body).length, 2);
        expect(body, contains('name="remove_image_ids"\r\n\r\n10'));
        expect(
          RegExp('name="images"; filename="photo.jpg"').allMatches(body).length,
          2,
        );
        expect(body, contains('content-type: image/jpeg'));
        return jsonResponse(sample());
      }),
    );
    api.beforeAuthorizedRequest = (m, p) => calls.add('$m $p');
    final jpeg = CommunityUpload(
      Uint8List.fromList([255, 216, 255, 1]),
      'untrusted-name.heic',
    );
    await ServerCommunityRepository(api).save(
      draft(images: [jpeg, jpeg], removed: [10, 11]),
      original: CommunityPost(sample()),
    );
    expect(calls, ['PATCH /api/posts/9']);
  });
  test('목록·댓글·좋아요·신고·차단은 계약 경로와 본문을 사용한다', () async {
    final seen = <String>[];
    final repo = ServerCommunityRepository(
      ApiClient(
        baseUrl: 'https://server.test',
        tokenStore: MemoryTokenStore(),
        client: MockClient((r) async {
          seen.add('${r.method} ${r.url.path}');
          switch (r.url.path) {
            case '/api/posts':
              expect(r.url.queryParameters, {
                'category': 'question',
                'page': '2',
                'page_size': '20',
              });
              return jsonResponse({
                'items': [sample()],
                'page': 2,
                'page_size': 20,
                'total': 21,
              });
            case '/api/posts/9/comments':
              if (r.method == 'GET') {
                return jsonResponse({
                  'items': [],
                  'page': 1,
                  'page_size': 20,
                  'total': 0,
                });
              }
              expect(jsonDecode(r.body), {'content': '답글', 'parent_id': 7});
              return jsonResponse({}, 201);
            case '/api/posts/9/likes':
              return jsonResponse({
                'post_id': 9,
                'like_count': 1,
                'liked_by_me': false,
              });
            case '/api/reports':
              expect(jsonDecode(r.body), {
                'target_type': 'comment',
                'target_id': 7,
                'reason': 'spam',
                'detail': '설명',
              });
              return jsonResponse({}, 201);
            case '/api/blocks':
              return jsonResponse({
                'items': [
                  {'user_id': 4, 'nickname': '작성자'},
                ],
                'page': 1,
                'page_size': 20,
                'total': 1,
              });
            default:
              return http.Response('', 204);
          }
        }),
      ),
    );
    expect((await repo.posts(category: 'question', page: 2)).total, 21);
    await repo.comments(9);
    await repo.comment(9, ' 답글 ', parentId: 7);
    await repo.deleteComment(9, 7);
    await repo.like(9, false);
    await repo.report('comment', 7, 'spam', ' 설명 ');
    expect((await repo.blocks()).items.single.id, 4);
    await repo.block(4);
    await repo.unblock(4);
    await repo.deletePost(9);
    expect(
      seen,
      containsAll([
        'DELETE /api/posts/9/comments/7',
        'DELETE /api/posts/9/likes',
        'POST /api/blocks/4',
        'DELETE /api/blocks/4',
        'DELETE /api/posts/9',
      ]),
    );
  });
  test('서버 404·세션 만료를 예시 글로 대체하지 않는다', () async {
    for (final status in [401, 404, 503]) {
      final tokens = MemoryTokenStore();
      await tokens.write('t');
      var expired = 0;
      final repo = ServerCommunityRepository(
        ApiClient(
          baseUrl: 'https://server.test',
          tokenStore: tokens,
          onSessionExpired: () async {
            expired++;
          },
          client: MockClient(
            (_) async => jsonResponse({
              'code': status == 401 ? 'UNAUTHORIZED' : 'NOT_FOUND',
              'message': '서버 안내',
              'status': status,
            }, status),
          ),
        ),
      );
      await expectLater(repo.posts(), throwsA(isA<ApiRequestError>()));
      expect(expired, status == 401 ? 1 : 0);
    }
  });
  test('제목·본문·사진 개수와 실제 JPG/PNG 형식을 검증한다', () async {
    expect(
      () => CommunityDraft(
        category: 'info',
        title: ' ',
        content: '내용',
      ).validate(),
      throwsStateError,
    );
    expect(
      () => CommunityDraft(
        category: 'info',
        title: '가' * 51,
        content: '내용',
      ).validate(),
      throwsStateError,
    );
    expect(
      () => CommunityDraft(
        category: 'notice',
        title: '제목',
        content: '내용',
      ).validate(),
      throwsStateError,
    );
    expect(
      () => CommunityUpload(Uint8List.fromList([1, 2, 3]), 'photo.jpg'),
      throwsStateError,
    );
    expect(
      () => CommunityUpload(Uint8List(10 * 1024 * 1024 + 1), 'photo.png'),
      throwsStateError,
    );
    final image = CommunityUpload(Uint8List.fromList([255, 216, 255]), 'x');
    expect(
      () => draft(
        images: [image, image, image],
      ).validate(original: CommunityPost(sample())),
      throwsStateError,
    );
    draft(
      images: [image, image],
      removed: [10],
    ).validate(original: CommunityPost(sample()));
  });
  test('미리보기는 계정 인스턴스별로 글·좋아요·댓글·차단을 분리한다', () async {
    final a = LocalCommunityRepository(() => '회원A'),
        b = LocalCommunityRepository(() => '회원B');
    final own = await a.save(draft());
    expect(own.author.name, '회원A');
    await a.like(own.id, true);
    await a.like(own.id, true);
    expect((await a.post(own.id)).likes, 1);
    await a.comment(own.id, '부모');
    final parent = (await a.comments(own.id)).items.single;
    await a.comment(own.id, '답글', parentId: parent.id);
    await a.deleteComment(own.id, parent.id);
    expect((await a.comments(own.id)).items.first.deleted, true);
    final other = (await a.posts(category: 'proof')).items.single;
    await a.block(other.author.id);
    expect((await a.posts(category: 'proof')).items, isEmpty);
    expect((await b.posts(category: 'proof')).items, hasLength(1));
    await a.unblock(other.author.id);
    expect((await a.posts(category: 'proof')).items, hasLength(1));
    await a.report('post', other.id, 'spam', '');
    await expectLater(a.report('post', other.id, 'spam', ''), throwsStateError);
    await expectLater(a.deletePost(other.id), throwsStateError);
    await a.deletePost(own.id);
    expect((await b.posts()).total, 3);
  });
  test('빠른 필터 전환 후 도착한 이전 응답을 버린다', () async {
    final repo = PendingRepository();
    final model = CommunityController(
      CommunityDependencies(repository: repo, picker: NoPicker()),
    );
    final first = model.load(), second = model.filter('proof');
    repo.requests[1].complete(
      CommunityPageResult([CommunityPost(sample(id: 2))], 1, 1),
    );
    await second;
    repo.requests[0].complete(
      CommunityPageResult([CommunityPost(sample(id: 1))], 1, 1),
    );
    await first;
    expect(model.items.single.id, 2);
    expect(repo.categories, [null, 'proof']);
    model.dispose();
  });
  test('페이지 추가 중복을 제거하고 실패 시 기존 목록을 보존한다', () async {
    final repo = PendingRepository();
    final model = CommunityController(
      CommunityDependencies(repository: repo, picker: NoPicker()),
    );
    var load = model.load();
    repo.requests[0].complete(
      CommunityPageResult([CommunityPost(sample())], 1, 3),
    );
    await load;
    load = model.load(more: true);
    repo.requests[1].completeError(StateError('연결 실패'));
    await load;
    expect(model.items.single.id, 9);
    expect(model.error, '연결 실패');
    load = model.load(more: true);
    repo.requests[2].complete(
      CommunityPageResult(
        [CommunityPost(sample()), CommunityPost(sample(id: 10))],
        2,
        2,
      ),
    );
    await load;
    expect(model.items.map((p) => p.id), [9, 10]);
    expect(model.hasMore, false);
    model.search('없는 검색어');
    expect(model.visible, isEmpty);
    model.dispose();
  });
  test('잘못된 서버 게시글 형식은 화면 빌드 전에 조회 오류로 처리한다', () async {
    final deps = CommunityDependencies(
      picker: NoPicker(),
      repository: ServerCommunityRepository(
        ApiClient(
          baseUrl: 'https://server.test',
          tokenStore: MemoryTokenStore(),
          client: MockClient(
            (_) async => jsonResponse({
              'items': [
                {'post_id': 1},
              ],
              'page': 1,
              'page_size': 20,
              'total': 1,
            }),
          ),
        ),
      ),
    );
    final model = CommunityController(deps);
    await model.load();
    expect(model.items, isEmpty);
    expect(model.error, isNotNull);
    model.dispose();
  });
}
