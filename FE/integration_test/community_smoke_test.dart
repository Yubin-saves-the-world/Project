import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:fe/features/photos/data/local_photo_repository.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/goal_body/data/local_goal_repository.dart';
import 'package:fe/features/goal_body/presentation/goal_dependencies.dart';
import 'package:fe/features/goal_body/presentation/pages/goal_body_page.dart';
import '../test/fakes/fake_onboarding_repository.dart';
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
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.textContaining('기기 미리보기'), findsNothing);
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
    await tap(t, find.byKey(const Key('community-like')));
    expect(find.byTooltip('좋아요 취소'), findsOneWidget);
    await enter(t, 'community-comment', '네이티브 댓글 입력');
    await tap(t, find.byTooltip('댓글 등록'));
    expect(find.text('네이티브 댓글 입력'), findsOneWidget);
    final own = (await repo.posts()).items.firstWhere(
      (p) => p.title == '네이티브 미리보기 운동',
    );
    expect((await repo.comments(own.id)).items.single.content, '네이티브 댓글 입력');
    expect(
      t
          .widget<TextField>(find.byKey(const Key('community-comment')))
          .controller!
          .text,
      isEmpty,
    );
    await tap(t, find.text('답글 달기'));
    await enter(t, 'community-comment', '네이티브 답글');
    await tap(t, find.byTooltip('댓글 등록'));
    expect(find.text('네이티브 답글'), findsNothing);
    await tap(t, find.text('답글 1개 보기'));
    expect(find.text('네이티브 답글'), findsOneWidget);
    await tap(t, find.text('답글 숨기기'));
    expect(find.text('네이티브 답글'), findsNothing);
    await tap(t, find.byTooltip('게시글 메뉴'));
    await tap(t, find.text('수정'));
    await enter(t, 'community-title', '수정한 미리보기 운동');
    await t.scrollUntilVisible(
      find.text('수정 완료'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(t, find.text('수정 완료'));
    expect(find.text('수정한 미리보기 운동'), findsNWidgets(2));
    await tap(t, find.byTooltip('게시글 메뉴'));
    await tap(t, find.text('삭제'));
    await tap(t, find.text('삭제').last);
    expect(find.text('수정한 미리보기 운동'), findsNothing);
    expect((await repo.posts()).total, 3);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('iOS 로컬 목표 사진 선택·실제 전처리·등록', (t) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/goal-qa-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(
      img.encodeJpg(
        img.Image(width: 120, height: 200)..clear(img.ColorRgb8(100, 130, 170)),
      ),
    );
    final photos = LocalPhotoRepository();
    final repo = LocalGoalRepository(photos: photos);
    final picker = FakePhotoPicker()
      ..nextPhoto = SelectedPhoto(
        path: file.path,
        byteLength: await file.length(),
      );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      if (await file.exists()) await file.delete();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GoalBodyPage(
          dependencies: GoalDependencies(
            repository: repo,
            photos: photos,
            picker: picker,
            localPreview: true,
          ),
        ),
      ),
    );
    await settle(t);
    await tap(t, find.text('사진 추가'));
    await tap(t, find.text('앨범에서 선택'));
    await tap(t, find.text('목표 저장'));
    expect((await repo.load())!.previewBytes, isNotEmpty);
    expect((await repo.load())!.summary, isNull);
    expect(find.text('로컬에 등록한 참고 사진이에요. AI 분석 결과가 아니에요.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
