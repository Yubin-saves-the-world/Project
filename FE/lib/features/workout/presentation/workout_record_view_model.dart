import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/workout_repository.dart';
import 'workout_dependencies.dart';

class WorkoutRecordViewModel extends ChangeNotifier {
  WorkoutRecordViewModel(this.dependencies, this.id);
  final WorkoutDependencies dependencies;
  final int id;
  WorkoutLog? log;
  bool loading = false,
      busy = false,
      needsReload = false,
      missing = false,
      deleted = false,
      _disposed = false;
  String? error, accessCode;
  bool get canEdit =>
      !loading &&
      !busy &&
      !needsReload &&
      !missing &&
      !deleted &&
      log?.status == 'completed';
  bool get canDelete =>
      !loading &&
      !busy &&
      !needsReload &&
      !missing &&
      !deleted &&
      ['completed', 'in_progress', 'aborted'].contains(log?.status);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _failure(Object e, {bool lookup = false}) {
    accessCode = e is ApiRequestError ? e.code : null;
    if (lookup && accessCode == 'NOT_FOUND') missing = true;
    error = accessCode == 'VERSION_CONFLICT'
        ? '다른 곳에서 먼저 수정했어요. 기록을 다시 확인한 뒤 수정해 주세요.'
        : e is StateError
        ? e.message.toString()
        : '기록을 처리하지 못했어요. 다시 시도해 주세요.';
  }

  Future<void> load() async {
    if (loading || busy || deleted) return;
    loading = true;
    error = null;
    accessCode = null;
    _notify();
    try {
      log = await dependencies.repository.detail(id);
      missing = false;
      needsReload = false;
    } catch (e) {
      needsReload = true;
      _failure(e, lookup: true);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> _write(Future<void> Function() action) async {
    busy = true;
    error = null;
    accessCode = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      needsReload = true;
      _failure(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> update(WorkoutSet set, Map<String, dynamic> body) async {
    if (!canEdit) return false;
    final w = body['weight_kg'], reps = body['reps'], rest = body['rest_sec'];
    if (w is! num ||
        !w.isFinite ||
        w < 0 ||
        w > 500 ||
        reps is! int ||
        reps < 1 ||
        reps > 100 ||
        (rest != null && (rest is! int || rest < 0 || rest > 3600)) ||
        body['is_done'] is! bool) {
      error = '무게 0~500kg, 횟수 1~100회, 휴식 0~3600초로 입력해 주세요.';
      _notify();
      return false;
    }
    return _write(() async {
      await dependencies.repository.update(id, set, body);
      log = await dependencies.repository.detail(id);
    });
  }

  Future<bool> deleteSet(WorkoutSet set) async {
    if (!canEdit) return false;
    return _write(() async {
      await dependencies.repository.deleteSet(id, set.id);
      log = await dependencies.repository.detail(id);
    });
  }

  Future<bool> delete() async {
    if (!canDelete) return false;
    return _write(() async {
      await dependencies.repository.cancel(id);
      deleted = true;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
