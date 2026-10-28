import 'dart:convert';
import 'package:fe/features/workout/data/workout_repository.dart';
import 'package:fe/features/workout/data/workout_draft_store.dart';

Map<String, dynamic> workoutJson({
  String status = 'in_progress',
  List<Map<String, dynamic>> sets = const [],
}) => {
  'log_id': 87,
  'exercise': {'exercise_id': 7, 'name': '바벨 스쿼트'},
  'routine_id': 44,
  'started_at': '2026-10-27T10:00:00Z',
  'status': status,
  'sets': sets,
};

class FakeWorkoutRepository implements WorkoutRepository {
  Map<String, dynamic> data = workoutJson();
  final additions = <Map<String, dynamic>>[];
  final edits = <Map<String, dynamic>>[];
  int starts = 0, cancels = 0, completions = 0;
  int? lastRoutine;
  bool loseResponse = false, failBeforeSave = false;
  Object? updateError;
  bool loseCompletionResponse = false;
  String? lastMemo;
  Map<String, dynamic>? completionResponse;
  @override
  Future<WorkoutLog> start(int id, {int? routineId}) async {
    starts++;
    lastRoutine = routineId;
    return detail(87);
  }

  @override
  Future<WorkoutLog> detail(int id) async => WorkoutLog.fromJson(data);
  @override
  Future<void> add(int id, Map<String, dynamic> body) async {
    additions.add(Map.of(body));
    if (failBeforeSave) throw StateError('네트워크 오류');
    final sets = data['sets'] as List;
    if (!sets.any((s) => s['client_set_id'] == body['client_set_id'])) {
      sets.add({
        ...body,
        'set_id': 842 + sets.length,
        'version': 1,
        'rest_sec': body['rest_sec'],
      });
    }
    if (loseResponse) throw StateError('응답 손실');
  }

  @override
  Future<void> update(int id, WorkoutSet set, Map<String, dynamic> body) async {
    edits.add({...body, 'version': set.version});
    if (updateError != null) throw updateError!;
    final list = data['sets'] as List;
    final n = list.indexWhere((e) => e['set_id'] == set.id);
    list[n] = Map<String, dynamic>.from({
      ...list[n] as Map,
      ...body,
      'version': set.version + 1,
    });
  }

  @override
  Future<void> deleteSet(int id, int setId) async {
    (data['sets'] as List).removeWhere((s) => s['set_id'] == setId);
  }

  @override
  Future<void> cancel(int id) async {
    cancels++;
  }

  @override
  Future<Map<String, dynamic>> complete(int id, {String? memo}) async {
    completions++;
    data['status'] = 'completed';
    lastMemo = memo;
    final response =
        completionResponse ??
        {
          'log_id': id,
          'completed_at': '2026-10-27T10:10:00Z',
          'duration_sec': 600,
          'set_count': 1,
          'total_volume_kg': 600,
          'routine_progress': null,
          'routine_status': null,
        };
    data.addAll({
      'completed_at': response['completed_at'],
      'duration_sec': response['duration_sec'],
      'total_volume_kg': response['total_volume_kg'],
      'set_count': response['set_count'],
      'memo': memo,
    });
    if (loseCompletionResponse) throw StateError('종료 응답 손실');
    return response;
  }
}

class MemoryWorkoutDraftStore implements WorkoutDraftStore {
  final values = <int, Map<String, dynamic>>{};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read(int id) async => Map<String, dynamic>.from(
    jsonDecode(jsonEncode(values[id] ?? {})) as Map,
  );
  @override
  Future<void> write(int id, Map<String, dynamic> value) async {
    if (fail) throw StateError('저장 공간 오류');
    values[id] = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(value)) as Map,
    );
  }
}
