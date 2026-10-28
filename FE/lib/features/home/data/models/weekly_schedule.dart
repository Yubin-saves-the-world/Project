class RoutineItem {
  const RoutineItem({
    required this.exercise,
    required this.sets,
    required this.reps,
  });
  final int exercise, sets, reps;
  Map<String, dynamic> toJson() => {
    'exercise': exercise,
    'sets': sets,
    'reps': reps,
  };
  factory RoutineItem.fromJson(Map<String, dynamic> json) => RoutineItem(
    exercise: json['exercise'] as int,
    sets: json['sets'] as int,
    reps: json['reps'] as int,
  );
}

class DayRoutine {
  DayRoutine({
    required this.title,
    required List<RoutineItem> items,
    this.rest = false,
    this.minutes,
  }) : items = List.unmodifiable(items);
  factory DayRoutine.rest() => DayRoutine(title: '휴식일', items: [], rest: true);
  final String title;
  final List<RoutineItem> items;
  final bool rest;
  final int? minutes;
  Map<String, dynamic> toJson() => {
    'title': title,
    'rest': rest,
    'minutes': minutes,
    'items': items.map((item) => item.toJson()).toList(),
  };
  factory DayRoutine.fromJson(Map<String, dynamic> json) => DayRoutine(
    title: json['title'] as String,
    rest: json['rest'] as bool,
    minutes: json['minutes'] as int?,
    items: (json['items'] as List)
        .map(
          (item) =>
              RoutineItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
  void validate(int catalogLength) {
    if (title.trim().isEmpty ||
        title.length > 40 ||
        (minutes != null && (minutes! < 1 || minutes! > 600)) ||
        (rest ? items.isNotEmpty : items.isEmpty) ||
        items.map((item) => item.exercise).toSet().length != items.length) {
      throw const FormatException('Invalid routine');
    }
    for (final item in items) {
      if (item.exercise < 0 ||
          item.exercise >= catalogLength ||
          item.sets < 1 ||
          item.sets > 20 ||
          item.reps < 1 ||
          item.reps > 100) {
        throw const FormatException('Invalid routine item');
      }
    }
  }
}

class RoutineRevision {
  const RoutineRevision(this.from, this.routine);
  final DateTime from;
  final DayRoutine routine;
}

/// 반복 변경의 적용 날짜를 남겨 과거 일정과 완료 기록을 다시 작성하지 않습니다.
class WeeklySchedule {
  WeeklySchedule({
    Map<int, List<RoutineRevision>>? weekly,
    Map<String, DayRoutine>? dates,
  }) : weekly = Map.unmodifiable(
         (weekly ?? {}).map(
           (key, value) =>
               MapEntry(key, List<RoutineRevision>.unmodifiable(value)),
         ),
       ),
       dates = Map.unmodifiable(dates ?? {});
  final Map<int, List<RoutineRevision>> weekly;
  final Map<String, DayRoutine> dates;
  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  DayRoutine? templateFor(DateTime day) {
    RoutineRevision? latest;
    for (final revision in weekly[day.weekday] ?? <RoutineRevision>[]) {
      if (!revision.from.isAfter(day) &&
          (latest == null || revision.from.isAfter(latest.from))) {
        latest = revision;
      }
    }
    return latest?.routine;
  }

  DayRoutine? forDate(DateTime day) => dates[dateKey(day)] ?? templateFor(day);
  WeeklySchedule changed(
    DateTime day,
    DayRoutine routine, {
    required bool repeat,
    required DateTime today,
  }) {
    final nextDates = Map<String, DayRoutine>.of(dates);
    if (!repeat) {
      nextDates[dateKey(day)] = routine;
      return WeeklySchedule(weekly: weekly, dates: nextDates);
    }
    final alreadyRepeating = (weekly[day.weekday]?.isNotEmpty ?? false);
    // Initial setup covers the selected week; subsequent edits take effect from today onward.
    final from = alreadyRepeating && day.isBefore(today) ? today : day;
    final next = weekly.map(
      (key, value) => MapEntry(key, List<RoutineRevision>.of(value)),
    );
    final revisions = next[day.weekday] ??= [];
    // A new future rule replaces scheduled revisions from its effective date.
    revisions.removeWhere((revision) => !revision.from.isBefore(from));
    revisions.add(RoutineRevision(from, routine));
    if (!day.isBefore(today)) nextDates.remove(dateKey(day));
    return WeeklySchedule(weekly: next, dates: nextDates);
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'weekly': weekly.map(
      (key, value) => MapEntry(
        '$key',
        value
            .map(
              (revision) => {
                'from': dateKey(revision.from),
                'routine': revision.routine.toJson(),
              },
            )
            .toList(),
      ),
    ),
    'dates': dates.map((key, value) => MapEntry(key, value.toJson())),
  };
  factory WeeklySchedule.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown schedule version');
    }
    return WeeklySchedule(
      weekly: (json['weekly'] as Map).map(
        (key, value) => MapEntry(
          int.parse(key as String),
          (value as List)
              .map(
                (entry) => RoutineRevision(
                  parseDate(entry['from'] as String),
                  DayRoutine.fromJson(
                    Map<String, dynamic>.from(entry['routine'] as Map),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      dates: (json['dates'] as Map).map(
        (key, value) => MapEntry(
          key as String,
          DayRoutine.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
    );
  }
  static DateTime parseDate(String key) {
    final date = DateTime.tryParse(key);
    if (date == null || dateKey(date) != key) {
      throw const FormatException('Invalid schedule date');
    }
    return date;
  }

  void validate(int catalogLength) {
    for (final entry in weekly.entries) {
      if (entry.key < 1 || entry.key > 7) {
        throw const FormatException('Invalid weekday');
      }
      final seen = <String>{};
      for (final revision in entry.value) {
        final key = dateKey(revision.from);
        if (!seen.add(key)) throw const FormatException('Duplicate revision');
        revision.routine.validate(catalogLength);
      }
    }
    for (final entry in dates.entries) {
      parseDate(entry.key);
      entry.value.validate(catalogLength);
    }
  }
}
