import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/exercise_repository.dart';
import '../data/models/exercise.dart';

class ExerciseListViewModel extends ChangeNotifier {
  ExerciseListViewModel(
    this.repository, {
    this.debounce = const Duration(milliseconds: 300),
  });
  final ExerciseRepository repository;
  final Duration debounce;
  ExerciseFilter filter = const ExerciseFilter();
  List<Exercise> items = const [];
  int page = 0, total = 0;
  bool loading = false, loadingMore = false;
  String? error, accessCode, queryError;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool get hasMore => items.length < total;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _timer?.cancel();
    if (queryError != null) return;
    await _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    accessCode = null;
    items = const [];
    page = 0;
    total = 0;
    _notify();
    try {
      final result = await repository.list(filter: filter);
      if (_disposed || generation != _generation) return;
      items = result.items;
      page = result.page;
      total = result.total;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void _error(Object e) {
    accessCode = e is ApiRequestError ? e.code : null;
    error = e is StateError
        ? e.message.toString()
        : '종목을 불러오지 못했어요. 연결 상태를 확인해 주세요.';
  }

  void change(ExerciseFilter value, {bool search = false}) {
    _timer?.cancel();
    _generation++;
    loadingMore = false;
    filter = value;
    error = null;
    accessCode = null;
    if (value.query.trim().length > 30) {
      loading = false;
      items = const [];
      total = 0;
      page = 0;
      queryError = '검색어는 30자 이하로 입력해 주세요.';
      _notify();
      return;
    }
    queryError = null;
    if (search) {
      loading = true;
      items = const [];
      page = 0;
      total = 0;
      _notify();
      _timer = Timer(debounce, _reload);
    } else {
      _reload();
    }
  }

  Future<void> more() async {
    if (loading || loadingMore || !hasMore) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    _notify();
    try {
      final result = await repository.list(filter: filter, page: page + 1);
      if (_disposed || generation != _generation) return;
      items = List.unmodifiable([
        ...items,
        ...result.items.where((e) => !items.any((old) => old.id == e.id)),
      ]);
      page = result.page;
      total = result.total;
    } catch (e) {
      if (!_disposed && generation == _generation) _error(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
