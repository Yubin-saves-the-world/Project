import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/goal_body/presentation/goal_dependencies.dart';
import 'package:fe/features/goal_body/presentation/pages/goal_body_page.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/pages/analysis_entry_page.dart';
import '../../fakes/fake_goal_repository.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';
import '../profile/my_page_test.dart' show capture;

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
    testWidgets('목표 설명 등록·변경 확인·삭제 취소/확정과 $scale배 글꼴', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeGoalRepository();
      final dependencies = GoalDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const Key('capture'),
            child: GoalBodyPage(dependencies: dependencies),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.text('목표 저장')).dy;
      await tester.tap(find.text('목표 저장'));
      await tester.pumpAndSettle();
      expect(repository.creates, 0);
      expect(find.text('사진을 추가하거나 목표를 설명해 주세요.'), findsOneWidget);
      expect(find.text('목표 저장').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('goal-description')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('goal-description')),
        '어깨와 등 근육을 키우고 싶어요.',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('목표 저장'));
      await tester.pumpAndSettle();
      expect(repository.creates, 1);
      expect(find.text('등록한 목표 체형'), findsOneWidget);
      expect(find.text('변경 저장').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('변경 저장')).dy, before);
      await capture(tester, 'goal-body-$scale');
      await tester.ensureVisible(find.byKey(const Key('goal-description')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('goal-description')), '새 목표');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('변경 저장'));
      await tester.pumpAndSettle();
      expect(repository.updates, 0);
      expect(find.text('목표 체형을 변경할까요?'), findsOneWidget);
      await tester.tap(find.text('변경'));
      await tester.pumpAndSettle();
      expect(repository.updates, 1);
      await tester.tap(find.byTooltip('목표 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      await tester.tap(find.byTooltip('목표 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 1);
      expect(find.text('어떤 체형을 목표로 하나요?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('pending은 비교 선택을 막고 목표 없이 분석을 제공한다', (tester) async {
    final repository = FakeGoalRepository()
      ..goal = goalFixture(status: AnalysisStatus.pending);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GoalBodyPage(
          chooseForAnalysis: true,
          dependencies: GoalDependencies(
            repository: repository,
            photos: FakePhotoRepository(),
            picker: FakePhotoPicker(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('이 목표로 비교'), findsNothing);
    expect(find.text('목표 없이 분석'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('분석의 목표 카드에서 등록한 설명 목표를 비교 대상으로 선택한다', (tester) async {
    final goals = FakeGoalRepository();
    final photos = FakePhotoRepository();
    final picker = FakePhotoPicker();
    final dependencies = AnalysisDependencies(
      repository: FakeAnalysisRepository(),
      photos: photos,
      picker: picker,
      pending: MemoryAnalysisPendingStore(),
      goals: GoalDependencies(
        repository: goals,
        photos: photos,
        picker: picker,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AnalysisEntryPage(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('목표 체형'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('목표 체형'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalBodyPage), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('goal-description')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal-description')), '어깨 발달');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('목표 저장'));
    await tester.pumpAndSettle();
    expect(goals.creates, 1);
    await tester.tap(find.text('이 목표로 비교'));
    await tester.pumpAndSettle();
    expect(find.text('목표 체형 선택됨 · 눌러서 변경하기'), findsOneWidget);
    expect(find.byType(GoalBodyPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
