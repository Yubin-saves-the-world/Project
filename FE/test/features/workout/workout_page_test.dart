import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/workout/presentation/pages/workout_page.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import '../../fakes/fake_workout_repository.dart';
import '../profile/my_page_test.dart' show capture;

void main() {
  setUpAll(() async {
    for (final f in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        f.key,
      )..addFont(rootBundle.load('assets/fonts/${f.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('운동 시작·세트 입력·수정·휴식·고정 종료 버튼 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeWorkoutRepository()..data = workoutJson(sets: []);
      repo.data['started_at'] = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const Key('capture'),
            child: WorkoutPage(
              dependencies: WorkoutDependencies(
                repository: repo,
                drafts: MemoryWorkoutDraftStore(),
              ),
              exerciseId: 7,
              routineId: 44,
              targetSets: 3,
              targetReps: 10,
              restSeconds: 120,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('바벨 스쿼트'), findsOneWidget);
      expect(find.text('종목 종료').hitTestable(), findsOneWidget);
      await capture(tester, 'workout-start-$scale');
      await tester.enterText(find.byKey(const Key('set-weight')), '60');
      await tester.enterText(find.byKey(const Key('set-reps')), '10');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('세트 완료'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('세트 완료'));
      await tester.pumpAndSettle();
      expect(repo.additions.length, 1);
      expect(find.text('종목 종료').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(find.text('휴식 중'), findsOneWidget);
      await capture(tester, 'workout-rest-$scale');
      await tester.ensureVisible(find.text('수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      expect(find.text('1세트 수정'), findsOneWidget);
      await tester.tap(find.text('변경'));
      await tester.pumpAndSettle();
      expect(repo.edits.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('저장 실패 오류가 나도 종료 버튼이 화면 안에 남는다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeWorkoutRepository()
      ..data = workoutJson(sets: [])
      ..failBeforeSave = true;
    repo.data['started_at'] = DateTime.now().toUtc().toIso8601String();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkoutPage(
          dependencies: WorkoutDependencies(
            repository: repo,
            drafts: MemoryWorkoutDraftStore(),
          ),
          exerciseId: 7,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('set-weight')), '60');
    await tester.enterText(find.byKey(const Key('set-reps')), '10');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('세트 완료'));
    await tester.pumpAndSettle();
    expect(find.text('네트워크 오류'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('종목 종료')).dy, lessThan(640));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
