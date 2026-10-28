import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/presentation/home_server_dependencies.dart';
import 'package:fe/features/home/presentation/home_server_view_model.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/data/models/server_home_data.dart';
import 'package:fe/features/exercises/data/models/exercise.dart';
import 'package:fe/features/workout/data/workout_repository.dart';
import 'package:fe/features/workout/presentation/pages/workout_page.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import '../../fakes/fake_home_repository.dart';
import '../../fakes/fake_home_server.dart';
import '../../fakes/fake_exercise_repository.dart';
import '../../fakes/fake_workout_repository.dart';

class RecordingWorkoutRepository extends FakeWorkoutRepository {
  int? requestedId;
  @override
  Future<WorkoutLog> start(int id, {int? routineId}) {
    requestedId = id;
    data = {
      ...workoutJson(),
      'exercise': {'exercise_id': id, 'name': '바벨 스쿼트'},
      'routine_id': routineId,
      'started_at': DateTime.now().toUtc().toIso8601String(),
    };
    return super.start(id, routineId: routineId);
  }
}

FakeHomeRepository schedule() =>
    FakeHomeRepository(emptySchedule: true)
      ..weeklySchedule = WeeklySchedule(
        dates: {
          '2026-10-26': DayRoutine(
            title: '내 운동',
            items: [const RoutineItem(exercise: 0, sets: 4, reps: 10)],
          ),
        },
      );
FakeExerciseRepository exercises() {
  const squat = Exercise(
    id: 1200,
    name: '바벨 스쿼트',
    targetPart: 'leg',
    equipment: 'barbell',
    difficulty: 2,
  );
  final repo = FakeExerciseRepository()..exercise = squat;
  repo.onList = (_, page) async => ExercisePageData([squat], page, 1);
  return repo;
}

void main() {
  testWidgets('수동 일정도 서버 운동 화면으로 이동하며 로컬 운동을 새로 쓰지 않는다', (tester) async {
    final manual = schedule(), routines = FakeHomeRoutines();
    final logs = RecordingWorkoutRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          today: DateTime(2026, 10, 26),
          repository: manual,
          server: HomeServerDependencies(
            repository: FakeHomeServer(routines),
            routines: routines,
            choices: FakeChoiceStore(),
            exercises: exercises(),
            workouts: WorkoutDependencies(
              repository: logs,
              drafts: MemoryWorkoutDraftStore(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('운동 시작'));
    await tester.tap(find.text('운동 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '바벨 스쿼트'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsOneWidget);
    expect(logs.requestedId, 1200);
    expect(logs.lastRoutine, isNull);
    expect(manual.writes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('수동 일정 완료 여부는 두 번째 서버 기록 페이지도 확인한다', () async {
    final manual = HomeViewModel(
      repository: schedule(),
      today: DateTime(2026, 10, 26),
    );
    await manual.initialize();
    final routines = FakeHomeRoutines();
    final api = FakeHomeServer(routines);
    api.onRecords = (a, b, page) async => ServerWorkoutPage(
      items: page == 1
          ? [serverWorkout(1)]
          : [
              ServerWorkoutRecord(
                id: 2,
                exerciseId: 1200,
                name: '바벨 스쿼트',
                date: DateTime(2026, 10, 26),
                status: 'completed',
                sets: 4,
                volume: 400,
                startedAt: DateTime.utc(2026, 10, 26),
              ),
            ],
      page: page,
      total: 2,
      count: 2,
      sets: 7,
      volume: 1600,
      dates: {'2026-10-26'},
    );
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: api,
        routines: routines,
        choices: FakeChoiceStore(),
        exercises: exercises(),
      ),
      manual,
    );
    await model.refresh();
    expect(model.dayError, isNull);
    expect(model.stats!.items.length, 2);
    expect(model.manualDone(0), true);
    expect(model.workoutDays, 1);
    model.dispose();
    manual.dispose();
  });
}
