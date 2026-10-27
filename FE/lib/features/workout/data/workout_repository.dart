import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';

class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.clientId,
    required this.number,
    required this.version,
    required this.weight,
    required this.reps,
    required this.done,
    this.rest,
  });
  final int id, number, version, reps;
  final String clientId;
  final num weight;
  final bool done;
  final int? rest;
  factory WorkoutSet.fromJson(Map<String, dynamic> j) => WorkoutSet(
    id: j['set_id'] as int,
    clientId: j['client_set_id'] as String,
    number: j['set_no'] as int,
    version: j['version'] as int,
    weight: j['weight_kg'] as num,
    reps: j['reps'] as int,
    done: j['is_done'] as bool,
    rest: j['rest_sec'] as int?,
  );
}

class WorkoutLog {
  WorkoutLog.fromJson(Map<String, dynamic> j)
    : id = j['log_id'] as int,
      exerciseId = (j['exercise'] as Map)['exercise_id'] as int,
      name = (j['exercise'] as Map)['name'] as String,
      routineId = j['routine_id'] as int?,
      startedAt = DateTime.parse(j['started_at'] as String),
      status = j['status'] as String,
      sets = List.unmodifiable(
        (j['sets'] as List)
            .map(
              (s) => WorkoutSet.fromJson(Map<String, dynamic>.from(s as Map)),
            )
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number)),
      );
  final int id, exerciseId;
  final int? routineId;
  final String name, status;
  final DateTime startedAt;
  final List<WorkoutSet> sets;
  bool activeAt(DateTime now) =>
      status == 'in_progress' &&
      now.difference(startedAt) < const Duration(hours: 6);
}

abstract interface class WorkoutRepository {
  Future<WorkoutLog> start(int exerciseId, {int? routineId});
  Future<WorkoutLog> detail(int id);
  Future<void> add(int id, Map<String, dynamic> body);
  Future<void> update(int id, WorkoutSet set, Map<String, dynamic> body);
  Future<void> deleteSet(int id, int setId);
  Future<void> cancel(int id);
  Future<Map<String, dynamic>> complete(int id);
}

class ServerWorkoutRepository implements WorkoutRepository {
  const ServerWorkoutRepository(this.api);
  final ApiClient api;
  @override
  Future<WorkoutLog> start(int exerciseId, {int? routineId}) async {
    final j = await api.send(
      'POST',
      ApiContract.workoutLogs,
      body: {'exercise_id': exerciseId, 'routine_id': ?routineId},
    );
    if (j == null || j['log_id'] is! int) {
      throw StateError('운동 시작 정보를 확인하지 못했어요. 다시 시도해 주세요.');
    }
    // Both 200 resumed and 201 new must load the server's existing sets.
    return detail(j['log_id'] as int);
  }

  @override
  Future<WorkoutLog> detail(int id) async {
    final j = await api.send('GET', ApiContract.workoutLog(id));
    if (j == null) throw StateError('운동 기록을 불러오지 못했어요.');
    return WorkoutLog.fromJson(j);
  }

  @override
  Future<void> add(int id, Map<String, dynamic> body) async {
    await api.send('POST', ApiContract.workoutSets(id), body: body);
  }

  @override
  Future<void> update(int id, WorkoutSet set, Map<String, dynamic> body) async {
    await api.send(
      'PATCH',
      ApiContract.workoutSet(id, set.id),
      body: {...body, 'version': set.version},
    );
  }

  @override
  Future<void> deleteSet(int id, int setId) async {
    await api.send('DELETE', ApiContract.workoutSet(id, setId));
  }

  @override
  Future<void> cancel(int id) async {
    await api.send('DELETE', ApiContract.workoutLog(id));
  }

  @override
  Future<Map<String, dynamic>> complete(int id) async {
    final j = await api.send(
      'PATCH',
      ApiContract.completeWorkout(id),
      body: {},
    );
    if (j == null) throw StateError('운동 종료 결과를 확인하지 못했어요. 기록을 다시 확인해 주세요.');
    return j;
  }
}
