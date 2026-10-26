import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../routines/data/models/routine.dart';
import '../data/models/server_home_data.dart';
import 'home_view_model.dart';
import 'home_server_dependencies.dart';

/// 서버 추천은 날짜별 별도 선택으로 적용한다. 기존 로컬 일정/기록의 번호나 원본은 수정하지 않는다.
class HomeServerViewModel extends ChangeNotifier {
  HomeServerViewModel(this.dependencies, this.local);
  final HomeServerDependencies dependencies;
  final HomeViewModel local;
  bool loading = false,
      dayLoading = false,
      busy = false,
      _disposed = false,
      choicesLoaded = false,
      activeLoaded = false;
  String? error, dayError, warning, accessCode;
  ServerWorkoutPage? stats;
  Set<String> completedDates = {};
  Set<String> _historyDates = {};
  List<ServerWorkoutRecord> active = [];
  int? analysisCount;
  Map<String, int> choices = {};
  final _pendingManualClear = <String>{};
  final routines = <String, RecommendedRoutine>{};
  int _generation = 0, _dayGeneration = 0;
  DateTime get selected => routineDate(local.selectedDate);
  RecommendedRoutine? get recommendation => routines[routineDateKey(selected)];
  bool get usesRecommended {
    final routine = recommendation;
    if (routine == null || !choicesLoaded || !local.loaded) return false;
    return choices[routineDateKey(selected)] == routine.id ||
        local.selectedRoutine == null;
  }

  bool planned(DateTime day) {
    final info = _summaries.where((d) => sameDate(d.date, day)).firstOrNull;
    final manual = local.routineFor(DateTime(day.year, day.month, day.day));
    if (info?.routine != null &&
        choicesLoaded &&
        local.loaded &&
        (manual == null || choices[routineDateKey(day)] == info!.routine!.id)) {
      final cached = routines[routineDateKey(day)];
      final status = cached?.id == info!.routine!.id
          ? cached!.status
          : info.routine!.status;
      return status == RoutineStatus.planned || status == RoutineStatus.done;
    }
    return local.planned(day);
  }

  int get workoutDays => completedDates.length;
  (int, bool) get streak {
    final today = routineDate(local.today),
        earliest = routineDate(local.today).subtract(const Duration(days: 91));
    var date = today;
    if (!_historyDates.contains(routineDateKey(date))) {
      date = date.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (!date.isBefore(earliest) &&
        _historyDates.contains(routineDateKey(date))) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return (count, count > 0 && date.isBefore(earliest));
  }

  String get streakLabel => loading
      ? '…'
      : error != null
      ? '—'
      : '${streak.$1}${streak.$2 ? '+' : ''}일';
  String get streakDescription => loading || error != null
      ? '서버 기록을 불러온 뒤 확인할 수 있어요.'
      : '${streak.$1}일${streak.$2 ? ' 이상' : ''} 연속 운동했어요.';
  bool get canMutate =>
      !loading &&
      !dayLoading &&
      !busy &&
      choicesLoaded &&
      activeLoaded &&
      local.canWrite &&
      error == null;
  bool _hasActive(DateTime date) =>
      active.any((r) => sameDate(r.date, date)) ||
      (local.active != null && sameDate(local.active!.date, date));
  bool get canChoose =>
      canMutate &&
      recommendation != null &&
      !selected.isBefore(routineDate(local.today)) &&
      recommendation!.status != RoutineStatus.done &&
      recommendation!.status != RoutineStatus.unknown &&
      !_hasActive(selected);
  num get volume =>
      (stats?.volume ?? 0) +
      active
          .where((r) => sameDate(r.date, selected))
          .fold<num>(0, (a, b) => a + b.volume);
  int get sets =>
      (stats?.sets ?? 0) +
      active
          .where((r) => sameDate(r.date, selected))
          .fold<int>(0, (a, b) => a + b.sets);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _message(Object e) =>
      e is StateError ? e.message.toString() : '서버 정보를 불러오지 못했어요. 다시 확인해 주세요.';
  void _access(Object e) {
    if (e is ApiRequestError) accessCode = e.code;
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    final generation = ++_generation;
    _dayGeneration++;
    loading = true;
    error = null;
    warning = null;
    accessCode = null;
    choicesLoaded = false;
    activeLoaded = false;
    _notify();
    final monday = routineMonday(local.today);
    final weeks = [
      monday,
      if (routineMonday(local.today.add(const Duration(days: 6))) != monday)
        routineMonday(local.today.add(const Duration(days: 6))),
    ];
    try {
      final results = await Future.wait<Object?>([
        dependencies.repository.today(),
        Future.wait(weeks.map(dependencies.routines.weekly)),
        dependencies.repository.records(
          monday,
          monday.add(const Duration(days: 6)),
          status: 'completed',
        ),
        dependencies.repository.active(routineDate(local.today)),
        dependencies.repository.analysisCount(),
        dependencies.choices.read(),
        dependencies.repository.records(
          routineDate(local.today).subtract(const Duration(days: 91)),
          routineDate(local.today),
          status: 'completed',
        ),
      ]);
      if (_disposed || generation != _generation) return;
      final loadedRoutines = <String, RecommendedRoutine>{};
      final today = results[0] as RecommendedRoutine?;
      if (today != null) loadedRoutines[routineDateKey(today.date)] = today;
      final summaries = (results[1] as List<RecommendedRoutineWeek>)
          .expand((w) => w.days)
          .where((d) => d.routine != null)
          .toList();
      final selectedSummary = summaries
          .where((d) => sameDate(d.date, selected))
          .firstOrNull;
      if (selectedSummary != null &&
          (!sameDate(selected, local.today) || today == null)) {
        final detail = await dependencies.routines.detail(
          selectedSummary.routine!.id,
        );
        loadedRoutines[routineDateKey(detail.date)] = detail;
      }
      if (_disposed || generation != _generation) return;
      routines
        ..clear()
        ..addAll(loadedRoutines);
      _summaries = summaries;
      completedDates = (results[2] as ServerWorkoutPage).dates;
      active = results[3] as List<ServerWorkoutRecord>;
      activeLoaded = true;
      _historyDates = (results[6] as ServerWorkoutPage).dates;
      analysisCount = results[4] as int;
      final loadedChoices = Map<String, int>.of(results[5] as Map<String, int>);
      if (_pendingManualClear.isNotEmpty) {
        for (final date in _pendingManualClear) {
          loadedChoices.remove(date);
        }
        await dependencies.choices.write(loadedChoices);
        if (_disposed || generation != _generation) return;
        _pendingManualClear.clear();
      }
      choices = loadedChoices;
      choicesLoaded = true;
      await _reconcile(generation);
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = _message(e);
        _access(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
    if (!_disposed && generation == _generation) await loadDay();
  }

  List<RecommendedRoutineDay> _summaries = [];
  Future<void> _reconcile(int generation) async {
    if (!local.canWrite || !choicesLoaded || !activeLoaded) return;
    for (final day in _summaries) {
      if (_disposed || generation != _generation) return;
      final summary = day.routine!;
      final manual = local.routineFor(
        DateTime(day.date.year, day.date.month, day.date.day),
      );
      if (day.date.isBefore(routineDate(local.today)) ||
          manual == null ||
          choices[routineDateKey(day.date)] == summary.id ||
          summary.status != RoutineStatus.planned ||
          _hasActive(day.date)) {
        continue;
      }
      try {
        final skipped = await dependencies.routines.setStatus(
          summary.id,
          RoutineStatus.skipped,
        );
        if (!_disposed && generation == _generation) {
          routines[routineDateKey(skipped.date)] = skipped;
        }
      } catch (e) {
        warning = '내 일정은 유지했지만 추천 건너뛰기를 반영하지 못했어요. 다시 확인해 주세요.';
        _access(e);
      }
    }
  }

  Future<void> loadDay() async {
    if (_disposed || busy) return;
    final generation = ++_dayGeneration;
    final date = selected;
    dayLoading = true;
    dayError = null;
    stats = null;
    _notify();
    try {
      final summary = _summaries
          .where((d) => sameDate(d.date, date))
          .firstOrNull;
      final result = await Future.wait<Object?>([
        dependencies.repository.records(date, date, status: 'completed'),
        if (summary != null &&
            routines[routineDateKey(date)]?.id != summary.routine!.id)
          dependencies.routines.detail(summary.routine!.id),
      ]);
      if (_disposed || generation != _dayGeneration) return;
      stats = result[0] as ServerWorkoutPage;
      if (result.length > 1) {
        final routine = result[1] as RecommendedRoutine;
        routines[routineDateKey(routine.date)] = routine;
      }
    } catch (e) {
      if (!_disposed && generation == _dayGeneration) {
        dayError = _message(e);
        _access(e);
      }
    } finally {
      if (!_disposed && generation == _dayGeneration) {
        dayLoading = false;
        _notify();
      }
    }
  }

  Future<bool> chooseRecommended() async {
    if (!canChoose) return false;
    final date = selected;
    final routine = recommendation!;
    busy = true;
    warning = null;
    _notify();
    try {
      final latest = await dependencies.routines.detail(routine.id);
      final running = await dependencies.repository.active(
        routineDate(local.today),
      );
      if (latest.status == RoutineStatus.done ||
          latest.status == RoutineStatus.unknown ||
          !sameDate(latest.date, date) ||
          running.any((r) => sameDate(r.date, date))) {
        warning = '루틴이나 진행 중인 운동이 변경됐어요. 다시 확인한 뒤 선택해 주세요.';
        return false;
      }
      final current = latest.status == RoutineStatus.skipped
          ? await dependencies.routines.setStatus(
              latest.id,
              RoutineStatus.planned,
            )
          : latest;
      final next = {...choices, routineDateKey(date): current.id};
      await dependencies.choices.write(next);
      if (!_disposed) {
        choices = next;
        routines[routineDateKey(date)] = current;
      }
      return true;
    } catch (e) {
      warning = '내 일정은 유지했어요. 추천 루틴을 적용하지 못했으니 다시 확인해 주세요.';
      _access(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> restoreRestDay() async {
    if (!canChoose || local.selectedRoutine?.rest != true) return false;
    return chooseRecommended();
  }

  Future<void> manualSaved() async {
    final key = routineDateKey(selected);
    _pendingManualClear.add(key);
    _generation++;
    _dayGeneration++;
    loading = false;
    dayLoading = false;
    busy = true;
    _notify();
    try {
      final saved = choicesLoaded ? choices : await dependencies.choices.read();
      final next = {...saved}..remove(key);
      await dependencies.choices.write(next);
      choices = next;
      _pendingManualClear.remove(key);
    } catch (e) {
      choicesLoaded = false;
      warning = '일정은 저장했지만 추천 선택을 갱신하지 못했어요. 다시 확인해 주세요.';
      busy = false;
      _notify();
      return;
    }
    busy = false;
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _dayGeneration++;
    super.dispose();
  }
}
