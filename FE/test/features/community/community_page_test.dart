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
      final repo = LocalCommunityRepository(() => '나');
      final deps = CommunityDependencies(
        repository: repo,
        picker: NoPicker(),
        preview: true,
      );
      await app(
        tester,
        MainShell(initialIndex: 4, community: deps),
        scale: scale,
      );
      expect(find.text('꾸준히 운동한 3개월의 기록'), findsOneWidget);
      expect(find.textContaining('기기 미리보기'), findsOneWidget);
      await capture(tester, 'community-list-$scale');
      await tester.tap(find.byTooltip('게시글 검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('community-search')), '스쿼트');
      await tester.pumpAndSettle();
      expect(find.text('꾸준히 운동한 3개월의 기록'), findsNothing);
      tester.testTextInput.hide();
      await tapText(tester, '스쿼트 60kg 넘겼습니다');
      await capture(tester, 'community-detail-$scale');
      expect(find.text('좋아요 0'), findsOneWidget);
      await tapText(tester, '좋아요 0');
      expect(find.text('좋아요 1'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('community-comment')));
      await tester.enterText(
        find.byKey(const Key('community-comment')),
        '좋은 기록이에요',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tapText(tester, '댓글 등록');
      expect(find.text('좋은 기록이에요'), findsOneWidget);
      await tapText(tester, '답글 달기');
      await tester.enterText(
        find.byKey(const Key('community-comment')),
        '답글입니다',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tapText(tester, '댓글 등록');
      expect(find.text('답글입니다'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('게시글 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('글쓰기'));
      await tester.pumpAndSettle();
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
    await tapText(tester, '작성자 차단');
    await tapText(tester, '차단');
    expect(find.text('스쿼트 60kg 넘겼습니다'), findsNothing);
    await tester.tap(find.byTooltip('커뮤니티 관리'));
    await tester.pumpAndSettle();
    await tapText(tester, '차단한 사용자');
    expect(find.text('예준'), findsOneWidget);
    await tapText(tester, '차단 해제');
    await tapText(tester, '차단 해제');
    expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.text('스쿼트 60kg 넘겼습니다'), findsOneWidget);
  });
  testWidgets('신고 사유 검증과 미리보기 표시를 제공한다', (tester) async {
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
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tapText(tester, '스팸·광고');
    await tapText(tester, '신고하기');
    expect(find.textContaining('실제 접수되지 않아요'), findsOneWidget);
  });
  testWidgets('내 글만 수정·삭제할 수 있다', (tester) async {
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
    expect(find.text('수정한 제목'), findsOneWidget);
    await tester.tap(find.byTooltip('게시글 메뉴'));
    await tester.pumpAndSettle();
    await tapText(tester, '삭제');
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
}
