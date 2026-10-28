import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/pages/analysis_run_page.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/routines/presentation/pages/routine_week_page.dart';
import 'package:fe/features/routines/presentation/pages/routine_detail_page.dart';
import 'package:fe/features/routines/data/local_routine_repository.dart';
import 'package:fe/features/exercises/presentation/pages/exercise_detail_page.dart';
import '../../fakes/fake_exercise_repository.dart';
import '../../fakes/fake_routine_repository.dart';
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

  testWidgets('분석 결과에서 생성한 ID로 상세와 주간 루틴을 연다', (tester) async {
    final routines = FakeRoutineRepository();
    final analysis = FakeAnalysisRepository()
      ..response = result(AnalysisStatus.done);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AnalysisRunPage(
          id: 31,
          dependencies: AnalysisDependencies(
            repository: analysis,
            photos: FakePhotoRepository(),
            picker: FakePhotoPicker(),
            pending: MemoryAnalysisPendingStore(),
            routines: routines,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('맞춤 루틴 만들기'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('맞춤 루틴 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    expect(analysis.generatedId, 31);
    await tester.scrollUntilVisible(find.text('루틴 상세 보기'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('루틴 상세 보기'));
    await tester.pumpAndSettle();
    expect(routines.details.last, 4);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('주간 루틴 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('주간 루틴 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineWeekPage), findsOneWidget);
    expect(analysis.generated, 1);
    expect(routines.weeks.last.weekday, DateTime.monday);
  });
  testWidgets('상세 변경 오류는 재조회로 복구하고 정상 상세 배치를 확인한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final routines = FakeRoutineRepository()
      ..patchError = StateError('다시 연결해 주세요.');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('capture'),
          child: RoutineDetailPage(
            repository: routines,
            id: 44,
            exercises: FakeExerciseRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'routine-detail');
    await tester.tap(find.text('이 루틴 건너뛰기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.text('다시 연결해 주세요.'), findsOneWidget);
    expect(find.text('이 루틴 건너뛰기'), findsNothing);
    routines.patchError = null;
    await tester.tap(find.text('다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('이 루틴 건너뛰기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('주간 7일·상세·운동 정보·건너뛰기 확인/되돌리기와 $scale배 글꼴', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeRoutineRepository();
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
            child: RoutineWeekPage(
              repository: repository,
              exercises: FakeExerciseRepository(),
              date: DateTime(2026, 10, 26),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'routine-week-$scale');
      expect(find.text('1/2종목 완료'), findsOneWidget);
      await tester.tap(find.text('상체 균형'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineDetailPage), findsOneWidget);
      expect(find.text('3세트 · 12회 · 무게 직접 입력'), findsOneWidget);
      await tester.ensureVisible(find.text('운동 정보 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('운동 정보 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 루틴 건너뛰기'));
      await tester.pumpAndSettle();
      expect(repository.patches, isEmpty);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.patches, isEmpty);
      await tester.tap(find.text('이 루틴 건너뛰기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(repository.patches.length, 1);
      await tester.tap(find.text('이 루틴 되돌리기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(repository.patches.length, 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('빈 추천 주간은 7일을 유지하고 자동 생성하거나 수동 휴식일로 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RoutineWeekPage(
          repository: LocalRoutineRepository(),
          date: DateTime(2026, 10, 26),
          localPreview: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('선택한 주에 추천된 루틴이 없어요.'), findsOneWidget);
    expect(find.text('휴식일'), findsNothing);
    await tester.tap(find.byTooltip('다음 주'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-11-02'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
