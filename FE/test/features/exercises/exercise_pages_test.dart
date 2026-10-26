import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/presentation/pages/weekly_routine_editor.dart';
import '../../fakes/fake_home_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/exercises/data/local_exercise_repository.dart';
import 'package:fe/features/exercises/presentation/pages/exercise_list_page.dart';
import 'package:fe/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';
import '../../fakes/fake_exercise_repository.dart';
import '../profile/my_page_test.dart' show capture;

void main() {
  testWidgets('일정 편집에서 종목 정보를 보고 돌아와도 입력 초안을 유지한다', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.light,
        home: HomePage(
          repository: FakeHomeRepository(emptySchedule: true),
          today: DateTime(2026, 10, 26),
          onOpenExercises: () => navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => ExerciseListPage(
                repository: LocalExerciseRepository(
                  () => ExperienceLevel.under3m,
                ),
                localPreview: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('routine-title')), '내 운동 일정');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('종목 정보'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('종목 정보'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseListPage), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRoutineEditor), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('routine-title')))
          .controller!
          .text,
      '내 운동 일정',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
    testWidgets('운동 검색·부위/기구/난이도·초기화·상세와 $scale배 글꼴', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
            child: ExerciseListPage(
              repository: LocalExerciseRepository(
                () => ExperienceLevel.under3m,
              ),
              localPreview: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'exercise-list-$scale');
      await tester.tap(find.widgetWithText(ChoiceChip, '하체'));
      await tester.pumpAndSettle();
      expect(find.text('4개 종목'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('exercise-search')), '바벨스쿼트');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.text('1개 종목'), findsOneWidget);
      await tester.ensureVisible(find.text('바벨 스쿼트'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('바벨 스쿼트'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
      expect(find.text('권장 2~3세트'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('초기화'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('초기화'));
      await tester.pumpAndSettle();
      expect(find.text('24개 종목'), findsOneWidget);
      await tester.tap(find.text('전체 기구'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('덤벨'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, '덤벨'), findsOneWidget);
      await tester.tap(find.text('전체 난이도'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('난이도 1 이하'));
      await tester.pumpAndSettle();
      expect(find.text('2개 종목'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('영상 링크 열기 실패·재시도와 상세 오류 복구', (tester) async {
    var opened = 0;
    final repository = FakeExerciseRepository()
      ..detailError = StateError('연결 실패');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ExerciseDetailPage(
          repository: repository,
          id: 1,
          openMedia: (uri) async {
            opened++;
            expect(uri.host, 'video.test');
            return opened > 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('연결 실패'), findsOneWidget);
    repository.detailError = null;
    repository.exercise = exerciseFixture(
      1,
      mediaUrl: 'https://video.test/demo.mp4',
    );
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('시범 영상 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시범 영상 보기'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('영상을 열지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    await tester.tap(find.text('시범 영상 보기'));
    await tester.pumpAndSettle();
    expect(opened, 2);
    expect(tester.takeException(), isNull);
  });
}
