import 'package:flutter/foundation.dart';
import '../../routines/data/models/routine.dart';
import '../data/workout_completion.dart';
import '../data/workout_repository.dart';
import 'workout_dependencies.dart';

class WorkoutSummaryViewModel extends ChangeNotifier {
  WorkoutSummaryViewModel(this.dependencies, this.log, this.result);
  final WorkoutDependencies dependencies;
  final WorkoutLog log;
  final WorkoutCompletion result;
  RecommendedRoutine? routine;
  bool loading = false, _disposed = false;
  String? error;
  bool get routineDone =>
      result.routineStatus == 'done' || routine?.status == RoutineStatus.done;
  bool get completedToday =>
      routineDate(
        routine?.date ?? log.startedAt.toUtc().add(const Duration(hours: 9)),
      ) ==
      routineToday();
  RecommendedRoutineItem? get nextItem {
    final r = routine;
    if (r == null ||
        routineDone ||
        r.status != RoutineStatus.planned ||
        routineDate(r.date) != routineToday()) {
      return null;
    }
    for (final item in r.items) {
      if (!item.done && item.exercise.id != log.exerciseId) return item;
    }
    return null;
  }

  String? get progress {
    if (log.routineId == null) return null;
    if (routine case final r?) {
      return '${r.items.where((e) => e.done).length}/${r.items.length}종목 완료';
    }
    if (result.done != null && result.total != null) {
      return '${result.done}/${result.total}종목 완료';
    }
    return null;
  }

  Future<void> load() async {
    if (loading || log.routineId == null || dependencies.routines == null) {
      return;
    }
    loading = true;
    error = null;
    _notify();
    try {
      final r = await dependencies.routines!.detail(log.routineId!);
      if (!_disposed) routine = r;
    } catch (_) {
      if (!_disposed) {
        routine = null;
        error = '추천 루틴을 확인하지 못했어요. 종료 기록은 저장되어 있어요.';
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<RecommendedRoutineItem?> next() async {
    if (loading) return null;
    await load();
    return error == null ? nextItem : null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
