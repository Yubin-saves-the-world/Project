import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/models/routine.dart';
import '../data/routine_repository.dart';

class RoutineWeekViewModel extends ChangeNotifier {
  RoutineWeekViewModel(this.repository, {DateTime? date})
    : start = routineMonday(date ?? routineToday());
  final RoutineRepository repository;
  DateTime start;
  RecommendedRoutineWeek? week;
  bool loading = false, _disposed = false;
  String? error, accessCode;
  int _generation = 0;
  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    accessCode = null;
    week = null;
    notifyListeners();
    try {
      final result = await repository.weekly(start);
      if (!_disposed && generation == _generation) week = result;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        accessCode = e is ApiRequestError ? e.code : null;
        error = e is StateError
            ? e.message.toString()
            : '주간 루틴을 불러오지 못했어요. 다시 시도해 주세요.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void move(int weeks) {
    start = start.add(Duration(days: 7 * weeks));
    load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
