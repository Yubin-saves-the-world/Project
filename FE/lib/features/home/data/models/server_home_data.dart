import '../../../routines/data/models/routine.dart';

class ServerWorkoutRecord {
  const ServerWorkoutRecord({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.date,
    required this.status,
    required this.sets,
    required this.volume,
    required this.startedAt,
    this.seconds,
  });
  final int id, exerciseId, sets;
  final String name, status;
  final DateTime date, startedAt;
  final num volume;
  final int? seconds;
  factory ServerWorkoutRecord.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercise'] as Map;
    return ServerWorkoutRecord(
      id: json['log_id'] as int,
      exerciseId: exercise['exercise_id'] as int,
      name: exercise['name'] as String,
      date: routineDate(DateTime.parse(json['workout_date'] as String)),
      status: json['status'] as String,
      sets: json['set_count'] as int,
      volume: json['total_volume_kg'] as num,
      startedAt: DateTime.parse(json['started_at'] as String),
      seconds: json['duration_sec'] as int?,
    );
  }
}

class ServerWorkoutPage {
  ServerWorkoutPage({
    required List<ServerWorkoutRecord> items,
    required this.page,
    required this.total,
    required this.count,
    required this.sets,
    required this.volume,
    this.seconds,
    required Set<String> dates,
  }) : items = List.unmodifiable(items),
       dates = Set.unmodifiable(dates);
  final List<ServerWorkoutRecord> items;
  final int page, total, count, sets;
  final int? seconds;
  final num volume;
  final Set<String> dates;
  factory ServerWorkoutPage.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map;
    return ServerWorkoutPage(
      items: (json['items'] as List)
          .map(
            (e) => ServerWorkoutRecord.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      page: json['page'] as int,
      total: json['total'] as int,
      count: summary['log_count'] as int,
      sets: summary['total_sets'] as int,
      volume: summary['total_volume_kg'] as num,
      seconds: summary['total_duration_sec'] as int?,
      dates: (summary['workout_dates'] as List).cast<String>().toSet(),
    );
  }
}
