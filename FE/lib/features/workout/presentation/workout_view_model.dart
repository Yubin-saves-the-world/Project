import '../data/workout_completion.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/workout_repository.dart';
import 'workout_dependencies.dart';

class WorkoutViewModel extends ChangeNotifier {
  WorkoutViewModel(
    this.dependencies, {
    required this.exerciseId,
    this.logId,
    this.routineId,
    this.restTarget = 90,
    this.targetSets,
    this.targetReps,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final WorkoutDependencies dependencies;
  final int? exerciseId, logId, routineId;
  final int restTarget;
  final int? targetSets, targetReps;
  final DateTime Function() now;
  WorkoutLog? log;
  Map<String, dynamic> draft = {};
  bool loading = false,
      busy = false,
      closed = false,
      _disposed = false,
      needsReload = false;
  String? error, accessCode;
  WorkoutCompletion? result;
  Map<String, dynamic>? get pending => draft['pending'] == null
      ? null
      : Map<String, dynamic>.from(draft['pending'] as Map);
  bool get canWrite =>
      !loading &&
      !busy &&
      !closed &&
      !needsReload &&
      log?.activeAt(now()) == true;
  int get elapsed => log == null
      ? 0
      : now().difference(log!.startedAt).inSeconds.clamp(0, 21600);
  DateTime? get restStarted =>
      DateTime.tryParse(draft['rest_started'] as String? ?? '');
  int get rested {
    final start = restStarted;
    if (start == null) return 0;
    final end =
        DateTime.tryParse(draft['rest_stopped'] as String? ?? '') ?? now();
    return end.difference(start).inSeconds.clamp(0, 3600);
  }

  int get remaining =>
      ((draft['rest_target'] as int? ?? restTarget) - rested).clamp(0, 3600);
  int get nextNumber {
    final highest = log?.sets.fold<int>(0, (n, s) => max(n, s.number)) ?? 0;
    return max(highest + 1, draft['next_number'] as int? ?? 1);
  }

  void changed() {
    if (!_disposed) notifyListeners();
  }

  void _failure(Object e) {
    error = e is StateError
        ? e.message.toString()
        : '요청을 처리하지 못했어요. 다시 시도해 주세요.';
    accessCode = e is ApiRequestError ? e.code : null;
  }

  Future<void> _persist() => dependencies.drafts.write(log!.id, Map.of(draft));
  Future<void> _readLog() async {
    log = await dependencies.repository.detail(log!.id);
    if (log!.status != 'in_progress') {
      draft = {};
      await _persist();
    }
    final p = pending;
    if (p != null && log!.sets.any((s) => s.clientId == p['client_set_id'])) {
      draft.remove('pending');
      await _persist();
    }
    needsReload = false;
  }

  Future<void> load() async {
    if (loading || busy || closed) return;
    loading = true;
    error = null;
    accessCode = null;
    changed();
    try {
      log = log != null
          ? await dependencies.repository.detail(log!.id)
          : logId != null
          ? await dependencies.repository.detail(logId!)
          : await dependencies.repository.start(
              exerciseId!,
              routineId: routineId,
            );
      draft = await dependencies.drafts.read(log!.id);
      if (log!.status == 'in_progress' && !draft.containsKey('rest_target')) {
        var seconds = restTarget;
        int? sets = log!.routineId == routineId ? targetSets : null;
        int? reps = log!.routineId == routineId ? targetReps : null;
        // A different device may not have local timer metadata. Recover the actual
        // server routine rather than applying a newly requested routine's target.
        if (log!.routineId != null && dependencies.routines != null) {
          final routine = await dependencies.routines!.detail(log!.routineId!);
          final items = routine.items.where(
            (e) => e.exercise.id == log!.exerciseId,
          );
          if (items.isNotEmpty) {
            final item = items.first;
            seconds = item.restSeconds;
            sets = item.sets;
            reps = item.reps;
          }
        }
        draft = {
          ...draft,
          'rest_target': seconds,
          'target_sets': ?sets,
          'target_reps': ?reps,
        };
        await _persist();
      }
      if (log!.status == 'completed') {
        result = WorkoutCompletion.fromLog(log!);
      }
      if (log!.status != 'in_progress') {
        draft = {};
        await _persist();
      }
      final p = pending;
      if (p != null && log!.sets.any((s) => s.clientId == p['client_set_id'])) {
        draft.remove('pending');
        await _persist();
      }
      needsReload = false;
    } catch (e) {
      needsReload = true;
      _failure(e);
    } finally {
      loading = false;
      changed();
    }
  }

  static String uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final h = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (!canWrite) return false;
    busy = true;
    error = null;
    accessCode = null;
    changed();
    try {
      await action();
      return true;
    } catch (e) {
      needsReload = true;
      _failure(e);
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<bool> add(num weight, int reps) async {
    if (pending != null || !canWrite) return false;
    if (!weight.isFinite ||
        weight < 0 ||
        weight > 500 ||
        reps < 1 ||
        reps > 100 ||
        nextNumber > 20) {
      error = '무게 0~500kg, 횟수 1~100회, 세트 1~20 범위로 입력해 주세요.';
      changed();
      return false;
    }
    return _mutate(() async {
      final body = <String, dynamic>{
        'client_set_id': uuid(),
        'set_no': nextNumber,
        'weight_kg': weight,
        'reps': reps,
        'is_done': true,
        if (restStarted != null) 'rest_sec': rested,
      };
      draft = {
        ...draft,
        'pending': body,
        'next_number': nextNumber + 1,
        'rest_started': now().toUtc().toIso8601String(),
        'rest_target': draft['rest_target'] ?? restTarget,
      }..remove('rest_stopped');
      // Persist before sending. A crash or lost response must reuse this exact UUID/body.
      await _persist();
      await dependencies.repository.add(log!.id, body);
      await _readLog();
    });
  }

  bool get conflictingPending =>
      pending != null &&
      !needsReload &&
      log!.sets.any(
        (s) =>
            s.number == pending!['set_no'] &&
            s.clientId != pending!['client_set_id'],
      );
  Future<void> discardConflictingPending() async {
    if (!canWrite || !conflictingPending) return;
    await _mutate(() async {
      draft.remove('pending');
      await _persist();
    });
  }

  Future<bool> retry() async {
    if (pending == null || !canWrite || conflictingPending) return false;
    return _mutate(() async {
      await _persist();
      await dependencies.repository.add(log!.id, pending!);
      await _readLog();
    });
  }

  Future<bool> update(
    WorkoutSet set,
    num weight,
    int reps, {
    bool? done,
  }) async {
    if (pending != null) return false;
    if (!weight.isFinite ||
        weight < 0 ||
        weight > 500 ||
        reps < 1 ||
        reps > 100) {
      error = '무게 0~500kg, 횟수 1~100회로 입력해 주세요.';
      changed();
      return false;
    }
    return _mutate(() async {
      await dependencies.repository.update(log!.id, set, {
        'weight_kg': weight,
        'reps': reps,
        'is_done': ?done,
      });
      await _readLog();
    });
  }

  Future<bool> deleteSet(WorkoutSet set) async {
    if (pending != null) return false;
    return _mutate(() async {
      draft['next_number'] = nextNumber;
      await _persist();
      await dependencies.repository.deleteSet(log!.id, set.id);
      await _readLog();
    });
  }

  Future<void> stopRest() async {
    if (!canWrite || restStarted == null) return;
    await _mutate(() async {
      draft['rest_stopped'] = now().toUtc().toIso8601String();
      await _persist();
    });
  }

  Future<bool> finish({String? memo}) async {
    if (pending != null) return false;
    if (memo != null && memo.length > 255) {
      error = '메모는 255자까지 입력할 수 있어요.';
      changed();
      return false;
    }
    return _mutate(() async {
      if (!log!.sets.any((s) => s.done)) {
        await dependencies.repository.cancel(log!.id);
      } else {
        try {
          draft['finish_memo'] = memo ?? '';
          await _persist();
          final response = await dependencies.repository.complete(
            log!.id,
            memo: memo,
          );
          result = WorkoutCompletion.fromJson(response, memo: memo);
        } on ApiRequestError catch (e) {
          if (e.code != 'WORKOUT_EMPTY') rethrow;
          await dependencies.repository.cancel(log!.id);
        }
      }
      closed = true;
      draft = {};
      await _persist();
    });
  }

  Future<bool> cancel() async => _mutate(() async {
    await dependencies.repository.cancel(log!.id);
    closed = true;
    draft = {};
    await _persist();
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
