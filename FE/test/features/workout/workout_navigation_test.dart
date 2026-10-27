import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/exercises/presentation/pages/exercise_detail_page.dart';
import 'package:fe/features/routines/presentation/pages/routine_detail_page.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/home_server_view_model.dart';
import 'package:fe/features/home/presentation/home_server_dependencies.dart';
import 'package:fe/features/home/presentation/widgets/server_home_cards.dart';
import 'package:fe/features/workout/presentation/pages/workout_page.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import '../../fakes/fake_workout_repository.dart';
import '../../fakes/fake_exercise_repository.dart';
import '../../fakes/fake_routine_repository.dart';
import '../../fakes/fake_home_repository.dart';
import '../../fakes/fake_home_server.dart';

void main() {
  late FakeWorkoutRepository workout;
  late WorkoutDependencies dependencies;
  setUp(() {
    workout = FakeWorkoutRepository()..data = workoutJson(sets: []);
    workout.data['started_at'] = DateTime.now().toUtc().toIso8601String();
    dependencies = WorkoutDependencies(
      repository: workout,
      drafts: MemoryWorkoutDraftStore(),
    );
  });
  testWidgets('운동 상세에서 자유 운동으로 시작하고 기존 화면으로 돌아간다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ExerciseDetailPage(
          repository: FakeExerciseRepository(),
          id: 7,
          workouts: dependencies,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 운동 시작'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 운동 시작'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsOneWidget);
    expect(workout.starts, 1);
    expect(workout.lastRoutine, isNull);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseDetailPage), findsOneWidget);
    expect(workout.cancels, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('추천 루틴에서는 routine_id와 목표를 전달하고 돌아오면 재조회한다', (tester) async {
    final routines = FakeRoutineRepository()
      ..routine = routineFixture(date: routineToday());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RoutineDetailPage(
          repository: routines,
          id: 44,
          workouts: dependencies,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 종목 시작 · 이어하기'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 종목 시작 · 이어하기'));
    await tester.pumpAndSettle();
    expect(workout.lastRoutine, 44);
    expect(find.text('목표 3세트 · 12회 · 휴식 90초'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(routines.details.length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('홈 이어하기는 POST 없이 기존 log_id를 조회한다', (tester) async {
    final routines = FakeHomeRoutines();
    final server = FakeHomeServer(routines);
    final local = HomeViewModel(
      repository: FakeHomeRepository(),
      today: DateTime(2026, 10, 26),
    );
    await local.initialize();
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: server,
        routines: routines,
        choices: FakeChoiceStore(),
        workouts: dependencies,
      ),
      local,
    );
    model.activeLoaded = true;
    model.active = [serverWorkout(87, status: 'in_progress')];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ServerHomeRecordCard(model: model, onRecords: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('이어하기 ·'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsOneWidget);
    expect(workout.starts, 0);
    expect(find.text('바벨 스쿼트'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
    local.dispose();
  });
}
