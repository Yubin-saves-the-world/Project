import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/workout/data/workout_completion.dart';
import 'package:fe/features/workout/data/workout_repository.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import 'package:fe/features/workout/presentation/workout_summary_view_model.dart';
import 'package:fe/features/workout/presentation/workout_view_model.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import '../../fakes/fake_workout_repository.dart';
import '../../fakes/fake_routine_repository.dart';
import '../../fakes/fake_exercise_repository.dart';

Map<String, dynamic> completedFixture({String? status = 'planned'}) => {
  'log_id': 87,
  'completed_at': '2026-10-27T10:10:00Z',
  'duration_sec': 612,
  'set_count': 4,
  'total_volume_kg': 1420.5,
  'routine_status': status,
  'routine_progress': status == null ? null : {'done': 1, 'total': 2},
};
RecommendedRoutine nextRoutine({
  RoutineStatus status = RoutineStatus.planned,
  bool done = false,
  DateTime? date,
}) => RecommendedRoutine(
  id: 44,
  analysisId: 31,
  date: date ?? routineToday(),
  title: '오늘 운동',
  part: 'back',
  minutes: 30,
  status: status,
  items: [
    RecommendedRoutineItem(
      id: 1,
      order: 1,
      exercise: exerciseFixture(7),
      sets: 3,
      reps: 12,
      restSeconds: 90,
      done: true,
    ),
    RecommendedRoutineItem(
      id: 2,
      order: 2,
      exercise: exerciseFixture(8),
      sets: 4,
      reps: 10,
      restSeconds: 120,
      done: done,
    ),
  ],
);
void main() {
  test('서버 확정 값과 자유 운동 null 진행률을 해석한다', () {
    final r = WorkoutCompletion.fromJson(
      completedFixture(status: null),
      memo: '메모',
    );
    expect(r.seconds, 612);
    expect(r.volume, 1420.5);
    expect(r.sets, 4);
    expect(r.done, isNull);
    expect(r.memo, '메모');
  });
  test('메모는 종료 API로 전달하고 255자 초과와 중복 제출을 막는다', () async {
    final repo = FakeWorkoutRepository()..data = workoutJson(sets: []);
    final m = WorkoutViewModel(
      WorkoutDependencies(repository: repo, drafts: MemoryWorkoutDraftStore()),
      exerciseId: 7,
      now: () => DateTime.utc(2026, 10, 27, 10, 10),
    );
    await m.load();
    await m.add(60, 10);
    expect(await m.finish(memo: '가' * 256), false);
    expect(repo.completions, 0);
    final results = await Future.wait([
      m.finish(memo: '컨디션 좋음'),
      m.finish(memo: '중복'),
    ]);
    expect(results, [true, false]);
    expect(repo.lastMemo, '컨디션 좋음');
    expect(m.result!.seconds, 600);
    expect(m.result!.memo, '컨디션 좋음');
    m.dispose();
  });
  test('종료 응답 손실 후 재조회는 PATCH 재전송 없이 완료 값과 메모를 복구한다', () async {
    final repo = FakeWorkoutRepository()
      ..data = workoutJson(sets: [])
      ..loseCompletionResponse = true;
    final store = MemoryWorkoutDraftStore();
    var m = WorkoutViewModel(
      WorkoutDependencies(repository: repo, drafts: store),
      exerciseId: 7,
      now: () => DateTime.utc(2026, 10, 27, 10, 10),
    );
    await m.load();
    await m.add(60, 10);
    expect(await m.finish(memo: '저장한 메모'), false);
    expect(m.needsReload, true);
    m.dispose();
    m = WorkoutViewModel(
      WorkoutDependencies(repository: repo, drafts: store),
      exerciseId: null,
      logId: 87,
    );
    await m.load();
    expect(repo.completions, 1);
    expect(m.result!.seconds, 600);
    expect(m.result!.volume, 600);
    expect(m.result!.memo, '저장한 메모');
    expect(m.canWrite, false);
    m.dispose();
  });
  test('다음 종목은 서버를 다시 확인하고 완료된 종목·현재 종목을 제외한다', () async {
    final routines = FakeRoutineRepository()..routine = nextRoutine();
    final log = WorkoutLog.fromJson(workoutJson(sets: []));
    final m = WorkoutSummaryViewModel(
      WorkoutDependencies(
        repository: FakeWorkoutRepository(),
        drafts: MemoryWorkoutDraftStore(),
        routines: routines,
      ),
      log,
      WorkoutCompletion.fromJson(completedFixture()),
    );
    await m.load();
    expect(m.nextItem!.exercise.id, 8);
    expect(m.progress, '1/2종목 완료');
    routines.routine = nextRoutine(status: RoutineStatus.done, done: true);
    expect(await m.next(), isNull);
    expect(m.routineDone, true);
    expect(m.progress, '2/2종목 완료');
    expect(routines.details, [44, 44]);
    m.dispose();
  });
  test('루틴 조회 오류는 종료 결과를 유지하고 재시도한다', () async {
    final routines = FakeRoutineRepository()..detailError = StateError('연결 오류');
    final m = WorkoutSummaryViewModel(
      WorkoutDependencies(
        repository: FakeWorkoutRepository(),
        drafts: MemoryWorkoutDraftStore(),
        routines: routines,
      ),
      WorkoutLog.fromJson(workoutJson(sets: [])),
      WorkoutCompletion.fromJson(completedFixture()),
    );
    await m.load();
    expect(m.error, isNotNull);
    expect(m.result.volume, 1420.5);
    expect(m.nextItem, isNull);
    routines.detailError = null;
    routines.routine = nextRoutine();
    await m.load();
    expect(m.error, isNull);
    expect(m.nextItem!.exercise.id, 8);
    m.dispose();
  });
  test('자유 운동·완료·건너뜀·지난/미래 루틴은 다음 종목을 시작하지 않는다', () async {
    for (final r in [
      nextRoutine(status: RoutineStatus.done, done: true),
      nextRoutine(status: RoutineStatus.skipped),
      nextRoutine(date: routineToday().subtract(const Duration(days: 1))),
      nextRoutine(date: routineToday().add(const Duration(days: 1))),
    ]) {
      final repo = FakeRoutineRepository()..routine = r;
      final m = WorkoutSummaryViewModel(
        WorkoutDependencies(
          repository: FakeWorkoutRepository(),
          drafts: MemoryWorkoutDraftStore(),
          routines: repo,
        ),
        WorkoutLog.fromJson(workoutJson(sets: [])),
        WorkoutCompletion.fromJson(completedFixture()),
      );
      await m.load();
      expect(m.nextItem, isNull);
      m.dispose();
    }
    final routines = FakeRoutineRepository();
    final j = workoutJson(sets: [])..['routine_id'] = null;
    final m = WorkoutSummaryViewModel(
      WorkoutDependencies(
        repository: FakeWorkoutRepository(),
        drafts: MemoryWorkoutDraftStore(),
        routines: routines,
      ),
      WorkoutLog.fromJson(j),
      WorkoutCompletion.fromJson(completedFixture(status: null)),
    );
    await m.load();
    expect(routines.details, isEmpty);
    expect(m.nextItem, isNull);
    expect(m.progress, isNull);
    m.dispose();
  });
}
