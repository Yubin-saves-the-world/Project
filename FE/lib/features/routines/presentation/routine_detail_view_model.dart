import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/models/routine.dart';
import '../data/routine_repository.dart';

class RoutineDetailViewModel extends ChangeNotifier {
  RoutineDetailViewModel(this.repository, this.id, {DateTime Function()? today})
    : _today = today ?? routineToday;
  final RoutineRepository repository;
  final int id;
  final DateTime Function() _today;
  RecommendedRoutine? routine;
  bool loading = false, busy = false, stale = false, _disposed = false;
  String? error, accessCode;
  int _generation = 0;
  bool get canSkip =>
      !loading && !busy && !stale && routine?.status == RoutineStatus.planned;
  bool get canRestore =>
      !loading &&
      !busy &&
      !stale &&
      routine?.status == RoutineStatus.skipped &&
      !routineDate(routine!.date).isBefore(routineDate(_today()));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _error(Object e) {
    accessCode = e is ApiRequestError ? e.code : null;
    error = e is StateError
        ? e.message.toString()
        : '추천 루틴을 확인하지 못했어요. 다시 시도해 주세요.';
  }

  Future<void> load() async {
    if (busy) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    accessCode = null;
    _notify();
    try {
      final response = await repository.detail(id);
      if (!_disposed && generation == _generation) {
        routine = response;
        stale = false;
      }
    } catch (e) {
      if (!_disposed && generation == _generation) {
        stale = true;
        _error(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> toggle() async {
    if (!canSkip && !canRestore) return;
    final status = canSkip ? RoutineStatus.skipped : RoutineStatus.planned;
    busy = true;
    error = null;
    accessCode = null;
    _notify();
    try {
      final response = await repository.setStatus(id, status);
      if (!_disposed) routine = response;
    } catch (e) {
      stale = true;
      _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
