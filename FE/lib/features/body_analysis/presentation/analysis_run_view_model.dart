import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/analysis_repository.dart';
import '../data/analysis_pending_store.dart';
import '../data/models/body_analysis.dart';

enum AnalysisRunPhase {
  loading,
  pending,
  done,
  failed,
  timedOut,
  networkError,
  unknown,
}

/// 화면을 떠나거나 앱이 비활성화되면 조회를 멈춘다. 재개는 같은 ID를 조회한다.
class AnalysisRunViewModel extends ChangeNotifier {
  AnalysisRunViewModel(
    this.repository,
    this.pending,
    this.id, {
    this.interval = const Duration(seconds: 2),
    this.maxWait = const Duration(seconds: 110),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final AnalysisRepository repository;
  final AnalysisPendingStore pending;
  final int id;
  final Duration interval, maxWait;
  final DateTime Function() _now;
  AnalysisRunPhase phase = AnalysisRunPhase.loading;
  BodyAnalysis? result;
  String? error, accessCode;
  Timer? _timer;
  int _generation = 0;
  DateTime? _started;
  bool _disposed = false;
  bool generating = false;
  List<AnalysisRoutine>? routines;
  String? routineError;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> resume() async {
    pause();
    _started = _now();
    phase = AnalysisRunPhase.loading;
    error = null;
    accessCode = null;
    _notify();
    await _poll(_generation);
  }

  void pause() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll(int generation) async {
    try {
      final remainingTime = maxWait - _now().difference(_started!);
      if (remainingTime <= Duration.zero) {
        phase = AnalysisRunPhase.timedOut;
        _notify();
        return;
      }
      final response = await repository.detail(id).timeout(remainingTime);
      if (_disposed || generation != _generation) return;
      result = response;
      phase = switch (response.status) {
        AnalysisStatus.pending => AnalysisRunPhase.pending,
        AnalysisStatus.done => AnalysisRunPhase.done,
        AnalysisStatus.failed => AnalysisRunPhase.failed,
        AnalysisStatus.unknown => AnalysisRunPhase.unknown,
      };
      if (phase == AnalysisRunPhase.done || phase == AnalysisRunPhase.failed) {
        try {
          await pending.clear(id);
        } catch (_) {}
        if (_disposed || generation != _generation) return;
      } else if (phase == AnalysisRunPhase.pending) {
        final remaining = maxWait - _now().difference(_started!);
        if (remaining <= Duration.zero) {
          phase = AnalysisRunPhase.timedOut;
        } else {
          _timer = Timer(remaining < interval ? remaining : interval, () {
            if (_now().difference(_started!) >= maxWait) {
              phase = AnalysisRunPhase.timedOut;
              _notify();
            } else {
              _poll(generation);
            }
          });
        }
      }
    } catch (e) {
      if (_disposed || generation != _generation) return;
      phase = e is TimeoutException
          ? AnalysisRunPhase.timedOut
          : AnalysisRunPhase.networkError;
      accessCode = e is ApiRequestError ? e.code : null;
      error = e is ApiRequestError
          ? e.message.toString()
          : '분석 상태를 확인하지 못했어요. 연결 상태를 확인한 뒤 다시 확인해 주세요.';
    }
    _notify();
  }

  Future<void> generate() async {
    if (_disposed ||
        generating ||
        result?.canGenerateRoutines != true ||
        result?.status != AnalysisStatus.done ||
        routines != null) {
      return;
    }
    generating = true;
    routineError = null;
    _notify();
    try {
      routines = await repository.generateRoutines(id);
    } catch (e) {
      routineError = e is StateError
          ? e.message.toString()
          : '루틴을 만들지 못했어요. 다시 시도해 주세요.';
    } finally {
      generating = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    super.dispose();
  }
}
