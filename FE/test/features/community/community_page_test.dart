import 'package:image/image.dart' as img;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/community/data/community_repository.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/app/shell/main_shell.dart';
import 'package:fe/features/community/data/community_models.dart';
import 'package:fe/features/community/data/local_community_repository.dart';
import 'package:fe/features/community/presentation/community_controller.dart';
import 'package:fe/features/community/presentation/community_page.dart';
import 'package:fe/features/community/presentation/community_editor_page.dart';
import 'package:fe/features/community/presentation/community_detail_page.dart';
import 'package:fe/features/community/presentation/community_widgets.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../profile/my_page_test.dart' show capture;
import 'community_repository_test.dart'
    show NoPicker, draft, sample, jsonResponse;

class WriteRepository extends LocalCommunityRepository {
  WriteRepository() : super(() => '내 계정');
  Completer<CommunityPost>? saving;
  int saves = 0;
  bool fail = false;
  @override
  Future<CommunityPost> save(
    CommunityDraft draft, {
    CommunityPost? original,
  }) async {
    saves++;
    if (fail) throw StateError('응답 유실');
    if (saving != null) return saving!.future;
    return super.save(draft, original: original);
  }
}

Future<void> app(WidgetTester tester, Widget child, {double scale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => RepaintBoundary(
        key: const Key('capture'),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  for (var i = 0; i < 12 && find.text(text).evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
  final found = find.text(text).last;
  await tester.ensureVisible(found);
  await tester.pumpAndSettle();
  await tester.tap(found);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final font in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('커뮤니티 목록·검색·상세·답글·글쓰기 배치 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var nickname = '이전닉네임';
      final repo = LocalCommunityRepository(() => nickname);
      final deps = CommunityDependencies(
        repository: repo,
        picker: NoPicker(),
        preview: true,
        currentNickname: () => nickname,
      );
      await app(
        tester,
        MainShell(initialIndex: 4, community: deps),
        scale: scale,
      );
      expect(find.text('꾸준히 운동한 3개월의 기록'), findsOneWidget);
      expect(find.textContaining('기기 미리보기'), findsNothing);
      expect(find.text('커뮤니티'), findsOneWidget);
      expect(find.byTooltip('게시글 검색'), findsNothing);
      expect(find.byTooltip('커뮤니티 관리'), findsNothing);
      expect(find.text('차단한 사용자 관리'), findsNothing);
      final search = find.byKey(const Key('community-search'));
      final menu = find.byKey(const Key('community-menu'));
      expect(
        tester.getCenter(menu).dy,
        closeTo(tester.getCenter(search).dy, .1),
      );
      expect(
        tester.getTopLeft(menu).dx,
        greaterThan(tester.getTopRight(search).dx),
      );
      expect(tester.getTopLeft(find.byType(ChoiceChip).first).dx, 24);
      await capture(tester, 'community-list-$scale');
      await tester.enterText(find.byKey(const Key('community-search')), '스쿼트');
      await tester.pumpAndSettle();
      expect(find.text('꾸준히 운동한 3개월의 기록'), findsNothing);
      tester.testTextInput.hide();
      await tapText(tester, '스쿼트 60kg 넘겼습니다');
      await capture(tester, 'community-detail-$scale');
      expect(find.textContaining('조회 '), findsNothing);
      expect(find.byKey(const Key('community-like')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('스쿼트 60kg 넘겼습니다'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('community-like'))).dx,
        tester.getTopLeft(find.byType(CommunityAvatar).first).dx,
      );
      await tester.tap(find.byKey(const Key('community-like')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('좋아요 취소'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('community-comment')));
      await tester.enterText(
        find.byKey(const Key('community-comment')),
        '좋은 기록이에요',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('댓글 등록'));
      await tester.pumpAndSettle();
      expect(find.text('좋은 기록이에요'), findsOneWidget);
      final comment = (await repo.comments(3)).items.first;
      expect(
        (tester
                    .getCenter(
                      find.byKey(ValueKey('comment-avatar-${comment.id}')),
                    )
                    .dy -
                tester
                    .getCenter(
                      find.byKey(ValueKey('comment-name-${comment.id}')),
                    )
                    .dy)
            .abs(),
        lessThan(1),
      );
      await tapText(tester, '답글 달기');
      await tester.enterText(
        find.byKey(const Key('community-comment')),
        '답글입니다',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('댓글 등록'));
      await tester.pumpAndSettle();
      expect(find.text('답글입니다'), findsNothing);
      await tapText(tester, '답글 1개 보기');
      expect(find.text('답글입니다'), findsOneWidget);
      await capture(tester, 'community-thread-$scale');
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('검색 지우기'));
      await tester.pumpAndSettle();
      nickname = '작성자닉네임';
      await tester.tap(find.byTooltip('글쓰기'));
      await tester.pumpAndSettle();
      expect(find.text('작성자닉네임'), findsOneWidget);
      expect(find.text('나의 이야기'), findsNothing);
      expect(find.text('이전닉네임'), findsNothing);
      await tester.enterText(find.byKey(const Key('community-title')), '나의 운동');
      await tester.enterText(
        find.byKey(const Key('community-content')),
        '오늘 운동했습니다.',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await capture(tester, 'community-editor-$scale');
      await tapText(tester, '게시하기');
      expect(find.text('나의 운동'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('다른 사용자 글 차단과 관리 화면 해제로 목록을 갱신한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LocalCommunityRepository(() => '나');
    final deps = CommunityDependencies(
      repository: repo,
      picker: NoPicker(),
      preview: true,
    );
    await app(tester, CommunityPage(dependencies: deps, isActive: true));
    await tapText(tester, '스쿼트 60kg 넘겼습니다');
    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('수정'), findsNothing);
    await capture(tester, 'community-action-sheet');
    await tapText(tester, '작성자 차단');
    await capture(tester, 'community-block-confirm');
    await tapText(tester, '차단');
    expect(find.text('스쿼트 60kg 넘겼습니다'), findsNothing);
    await tester.tap(find.byTooltip('커뮤니티 메뉴'));
    await tester.pumpAndSettle();
    await capture(tester, 'community-management-menu');
    await tapText(tester, '차단한 사용자 관리');
    expect(find.text('예준'), findsOneWidget);
    await tapText(tester, '차단 해제');
    await tapText(tester, '차단 해제');
    expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.text('스쿼트 60kg 넘겼습니다'), findsOneWidget);
  });
  testWidgets('신고 사유 검증과 미리보기 표시를 제공한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LocalCommunityRepository(() => '나');
    final deps = CommunityDependencies(
      repository: repo,
      picker: NoPicker(),
      preview: true,
    );
    await app(tester, CommunityDetailPage(dependencies: deps, postId: 2));
    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    await tapText(tester, '신고');
    await tapText(tester, '신고하기');
    expect(find.text('신고 사유를 선택해 주세요.'), findsOneWidget);
    await tapText(tester, '스팸·광고');
    await capture(tester, 'community-report');
    await tapText(tester, '신고하기');
    expect(find.text('현재 앱에서 신고한 항목으로 표시했어요.'), findsOneWidget);
  });
  testWidgets('작은 화면·확대 글꼴에서도 확인 버튼 크기와 정렬이 일치한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await app(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => communityConfirm(
                context,
                '게시글을 삭제할까요?',
                '게시글과 첨부 사진, 댓글을 다시 볼 수 없어요.',
                action: '삭제',
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
      scale: 1.3,
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    final cancel = tester.getRect(
      find.byKey(const Key('community-confirm-cancel')),
    );
    final action = tester.getRect(
      find.byKey(const Key('community-confirm-action')),
    );
    expect(action.size, cancel.size);
    expect(action.top, cancel.top);
    expect(action.width, greaterThan(70));
    expect(tester.takeException(), isNull);
    await capture(tester, 'community-delete-confirm-small');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('내 글만 수정·삭제할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LocalCommunityRepository(() => '나');
    final own = await repo.save(draft());
    final deps = CommunityDependencies(
      repository: repo,
      picker: NoPicker(),
      preview: true,
    );
    await app(tester, CommunityPage(dependencies: deps, isActive: true));
    await tapText(tester, own.title);
    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('신고'), findsNothing);
    await tapText(tester, '수정');
    await tester.enterText(find.byKey(const Key('community-title')), '수정한 제목');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tapText(tester, '수정 완료');
    expect(find.text('수정한 제목'), findsNWidgets(2));
    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    await capture(tester, 'community-own-actions');
    await tapText(tester, '삭제');
    final cancel = tester.getSize(
      find.byKey(const Key('community-confirm-cancel')),
    );
    final action = tester.getSize(
      find.byKey(const Key('community-confirm-action')),
    );
    expect(action, cancel);
    expect(action.height, greaterThanOrEqualTo(48));
    await capture(tester, 'community-delete-confirm');
    await tapText(tester, '삭제');
    expect(find.text('수정한 제목'), findsNothing);
  });
  testWidgets('응답 대기 중 중복 게시를 막고 오류 후 작성 내용을 유지한다', (tester) async {
    final repo = WriteRepository()..saving = Completer<CommunityPost>();
    final deps = CommunityDependencies(repository: repo, picker: NoPicker());
    await app(tester, CommunityEditorPage(dependencies: deps));
    await tester.enterText(find.byKey(const Key('community-title')), '보존할 제목');
    await tester.enterText(
      find.byKey(const Key('community-content')),
      '보존할 내용',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('게시하기'));
    await tester.tap(find.text('게시하기'));
    await tester.pump();
    expect(repo.saves, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.saving!.completeError(StateError('응답 유실'));
    await tester.pumpAndSettle();
    expect(find.text('보존할 제목'), findsOneWidget);
    expect(find.textContaining('처리 결과를 확인하지 못했어요'), findsOneWidget);
    expect(repo.saves, 1);
    await tapText(tester, '게시하기');
    expect(find.text('다시 전송할까요?'), findsOneWidget);
    await tapText(tester, '취소');
    expect(repo.saves, 1);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.text('작성을 그만할까요?'), findsOneWidget);
    await tapText(tester, '취소');
    expect(find.text('보존할 제목'), findsOneWidget);
  });
  testWidgets('서버 탭은 선택 시 조회하며 오류·빈 목록·실제 응답을 구분한다', (tester) async {
    var stage = 0, calls = 0;
    final data = sample(mine: false)..['images'] = [];
    final deps = CommunityDependencies(
      picker: NoPicker(),
      repository: ServerCommunityRepository(
        ApiClient(
          baseUrl: 'https://server.test',
          tokenStore: MemoryTokenStore(),
          client: MockClient((request) async {
            calls++;
            expect(request.url.path, '/api/posts');
            if (stage == 0) {
              return jsonResponse({
                'code': 'SERVICE_UNAVAILABLE',
                'message': '커뮤니티 서버 연결을 확인해 주세요.',
                'status': 503,
              }, 503);
            }
            return jsonResponse({
              'items': stage == 1 ? [] : [data],
              'page': 1,
              'page_size': 20,
              'total': stage == 1 ? 0 : 1,
            });
          }),
        ),
      ),
    );
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await app(tester, MainShell(initialIndex: 3, community: deps));
    expect(calls, 0);
    await tester.tap(find.byKey(const ValueKey('nav-커뮤니티')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('커뮤니티 서버 연결을 확인해 주세요.'), findsOneWidget);
    expect(find.textContaining('아직 게시글이 없어요'), findsNothing);
    expect(find.textContaining('기기 미리보기'), findsNothing);
    stage = 1;
    await tapText(tester, '다시 확인');
    expect(find.textContaining('아직 게시글이 없어요'), findsOneWidget);
    stage = 2;
    await tester.tap(find.byKey(const ValueKey('nav-인공지능 코치')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-커뮤니티')));
    await tester.pumpAndSettle();
    expect(find.text('운동 기록'), findsOneWidget);
    expect(calls, 3);
    await capture(tester, 'community-server-list');
  });
  testWidgets('목록 카드 높이·말줄임·오른쪽 이미지와 상세 전체 내용을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = LocalCommunityRepository(() => '작성자');
    final title = '긴 제목 ' * 8, content = '긴 본문을 상세에서 모두 확인해요. ' * 30;
    final bytes = Uint8List.fromList(
      img.encodeJpg(
        img.Image(width: 48, height: 64)..clear(img.ColorRgb8(120, 140, 180)),
      ),
    );
    final post = await repo.save(
      CommunityDraft(
        category: 'info',
        title: title,
        content: content,
        images: [CommunityUpload(bytes, 'photo.jpg')],
      ),
    );
    await app(
      tester,
      MainShell(
        initialIndex: 4,
        community: CommunityDependencies(
          repository: repo,
          picker: NoPicker(),
          preview: true,
        ),
      ),
    );
    final items = (await repo.posts()).items;
    for (final item in items) {
      expect(
        tester
            .getSize(find.byKey(ValueKey('community-card-${item.id}')))
            .height,
        148,
      );
      final card = tester.getRect(
        find.byKey(ValueKey('community-card-${item.id}')),
      );
      final reactions = tester.getRect(
        find.byKey(ValueKey('community-reactions-${item.id}')),
      );
      expect(reactions.right, closeTo(card.right - 16, 1));
    }
    final thumbSize = tester.getSize(
      find.byKey(ValueKey('community-thumbnail-${post.id}')),
    );
    expect(thumbSize.width, thumbSize.height);
    expect(tester.widget<Image>(find.byType(Image).first).fit, BoxFit.cover);
    final preview = tester.widget<Text>(find.text(content.trim()));
    expect(preview.maxLines, 2);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(
      tester
          .getTopLeft(find.byKey(ValueKey('community-thumbnail-${post.id}')))
          .dx,
      greaterThan(tester.getTopLeft(find.text(title.trim())).dx),
    );
    final image = tester.widget<Image>(find.byType(Image).first);
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(MainShell))),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'community-list-thumbnail');
    await tapText(tester, title.trim());
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(title.trim()),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      content.trim(),
    );
    final detailImage = tester.widget<Image>(find.byType(Image).first);
    expect(detailImage.fit, BoxFit.contain);
    await tester.runAsync(
      () => precacheImage(
        detailImage.image,
        tester.element(find.byType(CommunityDetailPage)),
      ),
    );
    await tester.pumpAndSettle();
    final fullSize = tester.getSize(find.byType(Image).first);
    expect(fullSize.height / fullSize.width, closeTo(64 / 48, .01));
    await tester.ensureVisible(find.byType(Image).first);
    await tester.pumpAndSettle();
    await capture(tester, 'community-image-full');
    expect(find.textContaining('기기 미리보기'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('긴 댓글은 접고 답글은 눌러서 펼친다 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = LocalCommunityRepository(() => '댓글 작성자');
      final post = await repo.save(draft());
      final text = '길게 작성한 댓글 내용입니다. ' * 20;
      await repo.comment(post.id, text);
      final parent = (await repo.comments(post.id)).items.single;
      await repo.comment(post.id, '숨겨진 답글입니다.', parentId: parent.id);
      final deps = CommunityDependencies(
        repository: repo,
        picker: NoPicker(),
        preview: true,
      );
      await app(
        tester,
        CommunityDetailPage(dependencies: deps, postId: post.id),
        scale: scale,
      );
      final content = find.byKey(ValueKey('comment-content-${parent.id}'));
      expect(tester.widget<Text>(content).maxLines, 3);
      expect(find.text('숨겨진 답글입니다.'), findsNothing);
      await tapText(tester, '더 보기');
      expect(tester.widget<Text>(content).maxLines, isNull);
      await tapText(tester, '간략히');
      expect(tester.widget<Text>(content).maxLines, 3);
      await tapText(tester, '답글 1개 보기');
      expect(find.text('숨겨진 답글입니다.'), findsOneWidget);
      await capture(tester, 'community-comment-fold-$scale');
      await tapText(tester, '답글 숨기기');
      expect(find.text('숨겨진 답글입니다.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
