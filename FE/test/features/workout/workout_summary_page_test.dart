import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/workout/data/workout_completion.dart';
import 'package:fe/features/workout/data/workout_repository.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import 'package:fe/features/workout/presentation/pages/workout_page.dart';
import 'package:fe/features/workout/presentation/pages/workout_summary_page.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'package:fe/app/shell/main_shell.dart';
import '../../fakes/fake_workout_repository.dart';
import '../../fakes/fake_routine_repository.dart';
import '../profile/my_page_test.dart' show capture;
import 'workout_summary_test.dart' show completedFixture, nextRoutine;

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
    for (final done in [false, true]) {
      testWidgets('서버 운동 요약·루틴 완료·홈 복귀 $scale $done', (tester) async {
        tester.view.physicalSize = scale == 1
            ? const Size(393, 852)
            : const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var home = 0;
        final routines = FakeRoutineRepository()
          ..routine = nextRoutine(
            status: done ? RoutineStatus.done : RoutineStatus.planned,
            done: done,
          );
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
              child: WorkoutSummaryPage(
                dependencies: WorkoutDependencies(
                  repository: FakeWorkoutRepository(),
                  drafts: MemoryWorkoutDraftStore(),
                  routines: routines,
                  onHome: () => home++,
                ),
                log: WorkoutLog.fromJson(workoutJson(sets: [])),
                result: WorkoutCompletion.fromJson(
                  completedFixture(status: done ? 'done' : 'planned'),
                  memo: '마지막 세트도 안정적으로 마쳤어요.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('10분 12초'), findsOneWidget);
        expect(find.text('1420.5kg'), findsOneWidget);
        expect(find.text('4세트'), findsOneWidget);
        expect(find.text('홈으로').hitTestable(), findsOneWidget);
        expect(find.text('다음 종목'), done ? findsNothing : findsOneWidget);
        if (done) expect(find.text('오늘 루틴 완료'), findsOneWidget);
        await capture(
          tester,
          'workout-summary-${done ? 'done' : 'next'}-$scale',
        );
        await tester.tap(find.text('홈으로'));
        expect(home, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('메모 저장 후 요약으로 교체하고 다음 종목을 명시적으로 시작한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeWorkoutRepository()
      ..data = workoutJson(sets: [])
      ..completionResponse = completedFixture();
    repo.data['started_at'] = DateTime.now().toUtc().toIso8601String();
    final routines = FakeRoutineRepository()..routine = nextRoutine();
    final deps = WorkoutDependencies(
      repository: repo,
      drafts: MemoryWorkoutDraftStore(),
      routines: routines,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) =>
            RepaintBoundary(key: const Key('capture'), child: child!),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutPage(
                    dependencies: deps,
                    exerciseId: 7,
                    routineId: 44,
                    targetReps: 12,
                  ),
                ),
              ),
              child: const Text('시작'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('set-weight')), '60');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('세트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('종목 종료'));
    await tester.pumpAndSettle();
    expect(repo.completions, 0);
    await tester.enterText(
      find.byKey(const Key('workout-memo')),
      '가벼운 무게로 마무리',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await capture(tester, 'workout-finish-memo');
    await tester.tap(find.text('기록 저장하고 종료'));
    await tester.pumpAndSettle();
    expect(repo.lastMemo, '가벼운 무게로 마무리');
    expect(repo.completions, 1);
    expect(find.byType(WorkoutSummaryPage), findsOneWidget);
    expect(find.byType(WorkoutPage), findsNothing);
    expect(find.text('가벼운 무게로 마무리'), findsOneWidget);
    expect(repo.starts, 1);
    // A new current log is returned only after the user presses Next.
    repo.data = workoutJson(sets: [])
      ..['log_id'] = 88
      ..['exercise'] = {'exercise_id': 8, 'name': '다음 운동'}
      ..['started_at'] = DateTime.now().toUtc().toIso8601String();
    await tester.tap(find.text('다음 종목'));
    await tester.pumpAndSettle();
    expect(repo.starts, 2);
    expect(repo.lastRoutine, 44);
    expect(find.byType(WorkoutPage), findsOneWidget);
    expect(find.text('다음 운동'), findsOneWidget);
    expect(find.text('목표 4세트 · 10회 · 휴식 120초'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('종료 응답 손실 후 다시 확인은 요약으로 복구한다', (tester) async {
    final repo = FakeWorkoutRepository()
      ..data = workoutJson(sets: [])
      ..loseCompletionResponse = true;
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
          targetReps: 10,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('set-weight')), '60');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('세트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('세트 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('종목 종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록 저장하고 종료'));
    await tester.pumpAndSettle();
    expect(find.text('종료 응답 손실'), findsOneWidget);
    await tester.tap(find.text('서버 기록 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutSummaryPage), findsOneWidget);
    expect(repo.completions, 1);
    expect(find.text('10분 0초'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('루틴 조회 실패해도 저장된 요약·홈 버튼을 표시한다', (tester) async {
    final routines = FakeRoutineRepository()..detailError = StateError('통신 실패');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkoutSummaryPage(
          dependencies: WorkoutDependencies(
            repository: FakeWorkoutRepository(),
            drafts: MemoryWorkoutDraftStore(),
            routines: routines,
          ),
          log: WorkoutLog.fromJson(workoutJson(sets: [])),
          result: WorkoutCompletion.fromJson(completedFixture()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1420.5kg'), findsOneWidget);
    expect(find.text('다음 종목'), findsNothing);
    expect(find.text('홈으로').hitTestable(), findsOneWidget);
    routines.detailError = null;
    routines.routine = nextRoutine();
    await tester.tap(find.text('루틴 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('다음 종목'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('분석 탭에서 시작해도 홈 요청은 홈 탭으로 복귀한다', (tester) async {
    final request = ValueNotifier<int>(0);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(initialIndex: 1, homeRequests: request),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('로그인 후 체형 분석을 이용해 주세요.'), findsOneWidget);
    request.value++;
    await tester.pumpAndSettle();
    expect(find.text('오늘의 루틴'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    request.dispose();
  });
}
