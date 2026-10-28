import 'package:flutter/foundation.dart';
import '../../home/data/home_server_repository.dart';
import '../../home/data/models/server_home_data.dart';
import '../../routines/data/models/routine.dart';

class WorkoutHistoryViewModel extends ChangeNotifier {
  WorkoutHistoryViewModel(
    this.repository, {
    DateTime? date,
    DateTime? today,
    DateTime Function()? now,
  }) : _clock = now ?? (() => today ?? routineToday()) {
    this.today = routineDate(_clock());
    selected = routineDate(date ?? this.today);
    if (selected.isAfter(this.today)) selected = this.today;
    month = DateTime.utc(selected.year, selected.month);
  }
  final DateTime Function() _clock;
  final HomeServerRepository repository;
  late DateTime today;
  late DateTime selected, month;
  ServerWorkoutPage? summary, day;
  List<ServerWorkoutRecord> items = [];
  String? status, monthError, dayError;
  bool monthLoading = false,
      dayLoading = false,
      moreLoading = false,
      _disposed = false;
  int _monthRequest = 0, _dayRequest = 0, _page = 0;
  bool get hasMore => day != null && items.length < day!.total;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    today = routineDate(_clock());
    await Future.wait([loadMonth(), loadDay()]);
  }

  Future<void> loadMonth() async {
    final request = ++_monthRequest;
    final start = month;
    monthLoading = true;
    summary = null;
    monthError = null;
    _notify();
    try {
      final data = await repository.records(
        start,
        DateTime.utc(start.year, start.month + 1, 0),
      );
      if (_disposed || request != _monthRequest) return;
      summary = data;
    } catch (_) {
      if (!_disposed && request == _monthRequest) {
        monthError = '이번 달 기록을 불러오지 못했어요.';
      }
    } finally {
      if (!_disposed && request == _monthRequest) {
        monthLoading = false;
        _notify();
      }
    }
  }

  Future<void> select(DateTime date) async {
    final d = routineDate(date);
    if (d.isAfter(today)) return;
    final changed = d.year != month.year || d.month != month.month;
    selected = d;
    month = DateTime.utc(d.year, d.month);
    await Future.wait([if (changed) loadMonth(), loadDay()]);
  }

  Future<void> changeMonth(int offset) =>
      select(DateTime.utc(month.year, month.month + offset));
  Future<void> filter(String? value) async {
    if (value == status) return;
    status = value;
    await loadDay();
  }

  Future<void> loadDay() async {
    final request = ++_dayRequest;
    dayLoading = true;
    moreLoading = false;
    dayError = null;
    day = null;
    items = [];
    _page = 0;
    _notify();
    await _fetch(request, 1);
  }

  Future<void> more() async {
    if (dayLoading || moreLoading || !hasMore) return;
    moreLoading = true;
    dayError = null;
    _notify();
    await _fetch(_dayRequest, _page + 1);
  }

  Future<void> _fetch(int request, int page) async {
    final date = selected, filter = status;
    try {
      final data = await repository.records(
        date,
        date,
        page: page,
        status: filter,
      );
      if (_disposed || request != _dayRequest) return;
      if (data.page != page ||
          (data.items.isEmpty && items.length < data.total)) {
        throw StateError('기록 페이지를 확인하지 못했어요.');
      }
      final fresh = data.items
          .where((e) => !items.any((old) => old.id == e.id))
          .toList();
      if (page > 1 && fresh.isEmpty && items.length < data.total) {
        throw StateError('기록 페이지가 반복되었어요.');
      }
      day = data;
      _page = page;
      items = [...items, ...fresh];
    } catch (_) {
      if (!_disposed && request == _dayRequest) {
        dayError = '선택한 날짜의 기록을 불러오지 못했어요.';
      }
    } finally {
      if (!_disposed && request == _dayRequest) {
        dayLoading = false;
        moreLoading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _monthRequest++;
    _dayRequest++;
    super.dispose();
  }
}
