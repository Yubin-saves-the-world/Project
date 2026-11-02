import 'package:flutter/foundation.dart';
import '../../exercises/data/models/exercise.dart';
import '../../routines/data/models/routine.dart';

/// Temporary UI sample. Disable with --dart-define=SHOW_ROUTINE_DEMO=false.
/// Never used in release builds or written to a repository.
abstract final class RecommendationDemo {
  static const enabled =
      kDebugMode &&
      bool.fromEnvironment('SHOW_ROUTINE_DEMO', defaultValue: true);

  static RecommendedRoutine forDate(DateTime date) => RecommendedRoutine(
    id: -1,
    analysisId: -1,
    date: routineDate(date),
    title: '등·어깨 균형 루틴',
    part: 'back',
    minutes: 35,
    status: RoutineStatus.planned,
    items: [
      for (final entry in const [
        ('랫 풀다운', 'back', 'machine', 12),
        ('시티드 로우', 'back', 'machine', 12),
        ('덤벨 숄더 프레스', 'shoulder', 'dumbbell', 10),
      ].indexed)
        RecommendedRoutineItem(
          id: -(entry.$1 + 1),
          order: entry.$1 + 1,
          exercise: Exercise(
            id: -(entry.$1 + 1),
            name: entry.$2.$1,
            targetPart: entry.$2.$2,
            equipment: entry.$2.$3,
            difficulty: 2,
          ),
          sets: 3,
          reps: entry.$2.$4,
          restSeconds: 90,
          done: false,
        ),
    ],
  );
}
