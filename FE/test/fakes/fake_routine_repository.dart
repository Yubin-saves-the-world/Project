import 'package:fe/features/routines/data/routine_repository.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'fake_exercise_repository.dart';

RecommendedRoutine routineFixture({
  RoutineStatus status = RoutineStatus.planned,
  DateTime? date,
}) => RecommendedRoutine(
  id: 44,
  analysisId: 31,
  date: date ?? DateTime(2099, 1, 5),
  title: '상체 균형',
  part: 'back',
  minutes: 35,
  status: status,
  items: [
    RecommendedRoutineItem(
      id: 201,
      order: 1,
      exercise: exerciseFixture(7),
      sets: 3,
      reps: 12,
      restSeconds: 90,
      done: false,
      reason: '등 근육을 균형 있게 사용하기 위한 운동이에요.',
    ),
  ],
);
RecommendedRoutineWeek weekFixture(DateTime monday) =>
    RecommendedRoutineWeek(monday, [
      for (var i = 0; i < 7; i++)
        RecommendedRoutineDay(
          monday.add(Duration(days: i)),
          i != 0,
          i == 0
              ? const RecommendedRoutineSummary(
                  id: 44,
                  title: '상체 균형',
                  part: 'back',
                  minutes: 35,
                  status: RoutineStatus.planned,
                  itemCount: 2,
                  doneCount: 1,
                )
              : null,
        ),
    ]);

class FakeRoutineRepository implements RoutineRepository {
  RecommendedRoutine routine = routineFixture();
  Object? detailError, patchError;
  Future<RecommendedRoutineWeek> Function(DateTime)? onWeek;
  Future<RecommendedRoutine> Function()? onDetail;
  final weeks = <DateTime>[];
  final details = <int>[];
  final patches = <(int, RoutineStatus)>[];
  @override
  Future<RecommendedRoutineWeek> weekly(DateTime monday) async {
    weeks.add(monday);
    return onWeek == null ? weekFixture(monday) : await onWeek!(monday);
  }

  @override
  Future<RecommendedRoutine> detail(int id) async {
    details.add(id);
    if (detailError != null) throw detailError!;
    return onDetail == null ? routine : await onDetail!();
  }

  @override
  Future<RecommendedRoutine> setStatus(int id, RoutineStatus status) async {
    patches.add((id, status));
    if (patchError != null) throw patchError!;
    return routine = routineFixture(status: status, date: routine.date);
  }
}
