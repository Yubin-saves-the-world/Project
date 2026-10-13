import 'package:flutter/foundation.dart';
import '../data/home_preview_repository.dart';

DateTime koreaToday([DateTime? instant]) {
  final now = (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  return DateTime(now.year, now.month, now.day);
}

bool sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class PreviewExercise {
  const PreviewExercise(this.name, this.sets, this.reps);
  final String name;
  final int sets, reps;
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.repository,
    DateTime? today,
    int frequency = 3,
    DateTime Function()? now,
  }) : _now =
           now ??
           (today == null
               ? DateTime.now
               : () => DateTime(today.year, today.month, today.day, 12)),
       today = today ?? koreaToday(now?.call()),
       frequency = frequency.clamp(1, 7) {
    selectedDate = this.today;
  }
  final HomePreviewRepository repository;
  final DateTime Function() _now;
  DateTime today;
  final int frequency;
  late DateTime selectedDate;
  bool loading = true, busy = false, _disposed = false;
  String? error;
  bool loaded = false;
  bool get canWrite => loaded && !loading && !busy;
  bool get isToday => sameDate(selectedDate, today);
  bool get routineDone => doneCount == exercises.length;
  bool exerciseDone(int index) => dayWorkouts.any((w) => w.exercise == index);
  List<PreviewWorkout> workouts = [];
  static const exercises = [
    PreviewExercise('바벨 스쿼트', 4, 12),
    PreviewExercise('루마니안 데드리프트', 4, 10),
    PreviewExercise('레그 프레스', 3, 15),
    PreviewExercise('레그 컬', 3, 12),
  ];
  DateTime get monday => today.subtract(Duration(days: today.weekday - 1));
  List<DateTime> get week =>
      List.generate(7, (i) => monday.add(Duration(days: i)));
  bool planned(DateTime day) => List.generate(
    frequency,
    (i) => i * 7 ~/ frequency,
  ).contains(day.weekday - 1);
  List<PreviewWorkout> get completed =>
      workouts.where((w) => w.completed && !w.aborted).toList();
  List<PreviewWorkout> get dayWorkouts =>
      completed.where((w) => sameDate(w.date, selectedDate)).toList();
  double get volume => dayWorkouts.fold(0, (total, w) => total + w.volume);
  int get totalSets => dayWorkouts.fold(0, (total, w) => total + w.sets);
  int get doneCount => dayWorkouts.map((w) => w.exercise).toSet().length;
  PreviewWorkout? get active {
    for (final w in workouts) {
      if (!w.completed && !w.aborted) return w;
    }
    return null;
  }

  int get workoutDays => completed
      .where(
        (w) =>
            !w.date.isBefore(monday) &&
            w.date.isBefore(monday.add(const Duration(days: 7))),
      )
      .map((w) => '${w.date.year}-${w.date.month}-${w.date.day}')
      .toSet()
      .length;
  int get streak {
    var d = today;
    final days = completed
        .map((w) => '${w.date.year}-${w.date.month}-${w.date.day}')
        .toSet();
    bool has(DateTime date) =>
        days.contains('${date.year}-${date.month}-${date.day}');
    if (!has(d)) d = d.subtract(const Duration(days: 1));
    var count = 0;
    while (has(d)) {
      count++;
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _validate(List<PreviewWorkout> records) {
    for (final w in records) {
      if (w.exercise < 0 ||
          w.exercise >= exercises.length ||
          !w.weight.isFinite ||
          w.weight < 0 ||
          w.weight > 500 ||
          w.reps < 0 ||
          w.reps > 100 ||
          w.sets < 0 ||
          w.sets > 20 ||
          (w.completed && (w.reps < 1 || w.sets < 1 || w.aborted))) {
        throw const FormatException('Invalid preview record');
      }
    }
    if (records.where((w) => !w.completed && !w.aborted).length > 1) {
      throw const FormatException('Multiple active workouts');
    }
  }

  List<PreviewWorkout> _expire(List<PreviewWorkout> value) => value
      .map(
        (w) =>
            !w.completed &&
                !w.aborted &&
                _now().difference(w.startedAt) > const Duration(hours: 6)
            ? w.markAborted()
            : w,
      )
      .toList();
  Future<void> initialize() async {
    if (busy) return;
    loading = true;
    loaded = false;
    error = null;
    _notify();
    try {
      final saved = await repository.load();
      _validate(saved);
      final next = _expire(saved);
      if (next.asMap().entries.any((e) => !identical(e.value, saved[e.key]))) {
        await repository.save(next);
      }
      workouts = next;
      loaded = true;
    } catch (_) {
      error = '기록을 불러오지 못했어요. 다시 불러온 뒤 운동을 시작해 주세요.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> refreshClock() async {
    final day = koreaToday(_now());
    if (!sameDate(today, day)) {
      final follow = isToday;
      today = day;
      if (follow) selectedDate = day;
      _notify();
    }
    if (!canWrite) return;
    final next = _expire(workouts);
    if (next.asMap().entries.any((e) => !identical(e.value, workouts[e.key]))) {
      if (!await _save(next)) {
        loaded = false;
        _notify();
      }
    }
  }

  void goToday() {
    selectedDate = today;
    _notify();
  }

  static double? parseWeight(String value) {
    final n = double.tryParse(value.trim());
    return n != null && n.isFinite && n >= 0 && n <= 500 ? n : null;
  }

  static int? parseCount(String value, int max) {
    final n = int.tryParse(value.trim());
    return n != null && n >= 1 && n <= max ? n : null;
  }

  void select(DateTime day) {
    selectedDate = day;
    _notify();
  }

  Future<bool> _save(List<PreviewWorkout> next) async {
    if (!canWrite) {
      return false;
    }
    busy = true;
    error = null;
    _notify();
    try {
      await repository.save(next);
      workouts = next;
      return true;
    } catch (_) {
      error = '기록을 저장하지 못했어요. 다시 시도해 주세요.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> start(int index) async {
    if (!canWrite) return false;
    await refreshClock();
    if (!canWrite) return false;
    if (!isToday) {
      error = '운동은 오늘 날짜에서만 시작할 수 있어요.';
      _notify();
      return false;
    }
    if (index < 0 || index >= exercises.length) return false;
    if (active != null) {
      if (active!.exercise == index) return true;
      error = '진행 중인 운동을 이어하거나 취소한 뒤 시작해 주세요.';
      _notify();
      return false;
    }
    if (exerciseDone(index)) {
      error = '오늘 이미 완료한 종목이에요.';
      _notify();
      return false;
    }
    return _save([
      ...workouts,
      PreviewWorkout(date: today, exercise: index, startedAt: _now()),
    ]);
  }

  Future<bool> cancelActive() async {
    final current = active;
    if (current == null || !canWrite) return false;
    return _save(workouts.where((w) => !identical(w, current)).toList());
  }

  Future<bool> complete(double weight, int reps, int sets) async {
    await refreshClock();
    final current = active;
    if (!canWrite ||
        current == null ||
        !weight.isFinite ||
        weight < 0 ||
        weight > 500 ||
        reps < 1 ||
        reps > 100 ||
        sets < 1 ||
        sets > 20) {
      return false;
    }
    final next = PreviewWorkout(
      date: current.date,
      exercise: current.exercise,
      startedAt: current.startedAt,
      weight: weight,
      reps: reps,
      sets: sets,
      completed: true,
    );
    final saved = await _save(
      workouts.map((w) => identical(w, current) ? next : w).toList(),
    );
    if (saved) {
      selectedDate = current.date;
      _notify();
    }
    return saved;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
