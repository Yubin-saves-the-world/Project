import 'workout_repository.dart';

/// Values confirmed by the server, never recomputed from the screen timer.
class WorkoutCompletion {
  const WorkoutCompletion({
    required this.id,
    required this.completedAt,
    required this.seconds,
    required this.volume,
    required this.sets,
    this.done,
    this.total,
    this.routineStatus,
    this.memo,
  });
  final int id, seconds, sets;
  final DateTime completedAt;
  final num volume;
  final int? done, total;
  final String? routineStatus, memo;
  factory WorkoutCompletion.fromJson(Map<String, dynamic> j, {String? memo}) {
    final progress = j['routine_progress'] as Map?;
    return WorkoutCompletion(
      id: j['log_id'] as int,
      completedAt: DateTime.parse(j['completed_at'] as String),
      seconds: j['duration_sec'] as int,
      volume: j['total_volume_kg'] as num,
      sets: j['set_count'] as int,
      done: progress?['done'] as int?,
      total: progress?['total'] as int?,
      routineStatus: j['routine_status'] as String?,
      memo: memo,
    );
  }
  factory WorkoutCompletion.fromLog(WorkoutLog log) {
    if (log.status != 'completed' ||
        log.completedAt == null ||
        log.duration == null ||
        log.volume == null ||
        log.setCount == null) {
      throw StateError('종료 결과를 확인하지 못했어요. 기록을 다시 불러와 주세요.');
    }
    return WorkoutCompletion(
      id: log.id,
      completedAt: log.completedAt!,
      seconds: log.duration!,
      volume: log.volume!,
      sets: log.setCount!,
      memo: log.memo,
    );
  }
}
