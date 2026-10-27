import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fe/app/shell/main_shell.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/community/data/community_models.dart';
import 'package:fe/features/community/data/community_repository.dart';
import 'package:fe/features/community/data/local_community_repository.dart';
import 'package:fe/features/community/presentation/community_controller.dart';
import 'native_smoke_test.dart' show tap, enter, settle;

class NoCommunityPhotos implements CommunityImagePicker {
  @override
  Future<List<CommunityUpload>> pick(int remaining) async => [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iOS 커뮤니티 미리보기: 목록·게시·좋아요·댓글·수정·삭제', (t) async {
    final repo = LocalCommunityRepository(() => '커뮤니티 QA');
    final deps = CommunityDependencies(
      repository: repo,
      picker: NoCommunityPhotos(),
      preview: true,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(initialIndex: 4, community: deps),
      ),
    );
    await settle(t);
    expect(find.text('커뮤니티'), findsNWidgets(2));
    expect(find.textContaining('실제 게시/전송 없음'), findsOneWidget);
    await tap(t, find.byTooltip('글쓰기'));
    await enter(t, 'community-title', '네이티브 미리보기 운동');
    await enter(t, 'community-content', '실제 서버에 전송하지 않는 UI 검증입니다.');
    await t.scrollUntilVisible(
      find.text('게시하기'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(t, find.text('게시하기'));
    await tap(t, find.text('네이티브 미리보기 운동'));
    await tap(t, find.text('좋아요 0'));
    expect(find.text('좋아요 1'), findsOneWidget);
    await enter(t, 'community-comment', '네이티브 댓글 입력');
    await tap(t, find.text('댓글 등록'));
    expect(find.text('네이티브 댓글 입력'), findsOneWidget);
    await tap(t, find.byTooltip('게시글 메뉴'));
    await tap(t, find.text('수정'));
    await enter(t, 'community-title', '수정한 미리보기 운동');
    await t.scrollUntilVisible(
      find.text('수정 완료'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(t, find.text('수정 완료'));
    expect(find.text('수정한 미리보기 운동'), findsOneWidget);
    await tap(t, find.byTooltip('게시글 메뉴'));
    await tap(t, find.text('삭제'));
    await tap(t, find.text('삭제').last);
    expect(find.text('수정한 미리보기 운동'), findsNothing);
    expect((await repo.posts()).total, 3);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
