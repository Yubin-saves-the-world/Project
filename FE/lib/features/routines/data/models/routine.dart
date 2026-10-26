import '../../../exercises/data/models/exercise.dart';

enum RoutineStatus { planned, done, skipped, unknown }

RoutineStatus routineStatus(Object? value) => RoutineStatus.values.firstWhere(
  (e) => e.name == value,
  orElse: () => RoutineStatus.unknown,
);
String routineStatusLabel(RoutineStatus value) => switch (value) {
  RoutineStatus.planned => '예정',
  RoutineStatus.done => '완료',
  RoutineStatus.skipped => '건너뜀',
  RoutineStatus.unknown => '상태 확인 필요',
};
DateTime routineDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
DateTime routineToday() =>
    routineDate(DateTime.now().toUtc().add(const Duration(hours: 9)));
DateTime routineMonday(DateTime value) {
  final date = routineDate(value);
  return date.subtract(Duration(days: date.weekday - 1));
}

String routineDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String routineDayLabel(DateTime date) =>
    '${date.month}월 ${date.day}일 (${const ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1]})';

class RecommendedRoutineItem {
  const RecommendedRoutineItem({
    required this.id,
    required this.order,
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.done,
    this.weightKg,
    this.reason,
  });
  final int id, order, sets, reps, restSeconds;
  final Exercise exercise;
  final bool done;
  final num? weightKg;
  final String? reason;
  String get weightLabel => weightKg == null ? '직접 입력' : '${weightKg}kg';
  factory RecommendedRoutineItem.fromJson(Map<String, dynamic> json) =>
      RecommendedRoutineItem(
        id: json['item_id'] as int,
        order: json['order_no'] as int,
        exercise: Exercise.fromJson(
          Map<String, dynamic>.from(json['exercise'] as Map),
        ),
        sets: json['target_sets'] as int,
        reps: json['target_reps'] as int,
        restSeconds: json['rest_sec'] as int,
        done: json['done'] as bool,
        weightKg: json['target_weight_kg'] as num?,
        reason: json['reason'] as String?,
      );
}

class RecommendedRoutine {
  RecommendedRoutine({
    required this.id,
    required this.analysisId,
    required this.date,
    required this.title,
    required this.part,
    required this.minutes,
    required this.status,
    required List<RecommendedRoutineItem> items,
  }) : items = List.unmodifiable(
         List<RecommendedRoutineItem>.of(items)
           ..sort((a, b) => a.order.compareTo(b.order)),
       );
  final int id, analysisId, minutes;
  final DateTime date;
  final String title, part;
  final RoutineStatus status;
  final List<RecommendedRoutineItem> items;
  factory RecommendedRoutine.fromJson(Map<String, dynamic> json) =>
      RecommendedRoutine(
        id: json['routine_id'] as int,
        analysisId: json['analysis_id'] as int,
        date: routineDate(DateTime.parse(json['scheduled_date'] as String)),
        title: json['title'] as String,
        part: json['target_part'] as String,
        minutes: json['estimated_minutes'] as int,
        status: routineStatus(json['status']),
        items: (json['items'] as List)
            .map(
              (e) => RecommendedRoutineItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}

class RecommendedRoutineSummary {
  const RecommendedRoutineSummary({
    required this.id,
    required this.title,
    required this.part,
    required this.minutes,
    required this.status,
    required this.itemCount,
    required this.doneCount,
  });
  final int id, minutes, itemCount, doneCount;
  final String title, part;
  final RoutineStatus status;
  bool get validProgress =>
      itemCount >= 0 && doneCount >= 0 && doneCount <= itemCount;
  String get progressLabel =>
      validProgress ? '$doneCount/$itemCount종목 완료' : '진행 정보 확인 필요';
  factory RecommendedRoutineSummary.fromJson(Map<String, dynamic> json) =>
      RecommendedRoutineSummary(
        id: json['routine_id'] as int,
        title: json['title'] as String,
        part: json['target_part'] as String,
        minutes: json['estimated_minutes'] as int,
        status: routineStatus(json['status']),
        itemCount: json['item_count'] as int,
        doneCount: json['done_count'] as int,
      );
}

class RecommendedRoutineDay {
  const RecommendedRoutineDay(this.date, this.isRestDay, this.routine);
  final DateTime date;
  final bool isRestDay;
  final RecommendedRoutineSummary? routine;
  factory RecommendedRoutineDay.fromJson(Map<String, dynamic> json) =>
      RecommendedRoutineDay(
        routineDate(DateTime.parse(json['date'] as String)),
        json['is_rest_day'] as bool,
        json['routine'] == null
            ? null
            : RecommendedRoutineSummary.fromJson(
                Map<String, dynamic>.from(json['routine'] as Map),
              ),
      );
}

class RecommendedRoutineWeek {
  RecommendedRoutineWeek(this.start, List<RecommendedRoutineDay> days)
    : days = List.unmodifiable(days) {
    if (start.weekday != DateTime.monday ||
        days.length != 7 ||
        List.generate(7, (i) => i).any(
          (i) =>
              routineDateKey(days[i].date) !=
              routineDateKey(start.add(Duration(days: i))),
        )) {
      throw const FormatException('주간 루틴 날짜가 올바르지 않아요.');
    }
  }
  final DateTime start;
  final List<RecommendedRoutineDay> days;
  bool get empty => days.every((d) => d.routine == null && d.isRestDay);
  factory RecommendedRoutineWeek.fromJson(Map<String, dynamic> json) =>
      RecommendedRoutineWeek(
        routineDate(DateTime.parse(json['week_start'] as String)),
        (json['days'] as List)
            .map(
              (d) => RecommendedRoutineDay.fromJson(
                Map<String, dynamic>.from(d as Map),
              ),
            )
            .toList(),
      );
}
