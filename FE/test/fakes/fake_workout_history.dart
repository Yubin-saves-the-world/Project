import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/home/data/models/server_home_data.dart';
import 'package:fe/features/workout/data/workout_repository.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'fake_home_server.dart';
import 'fake_workout_repository.dart';

ServerWorkoutRecord historyRecord(
  int id, {
  String status = 'completed',
  int day = 26,
  num volume = 760,
}) => ServerWorkoutRecord(
  id: id,
  exerciseId: 7,
  name: '바벨 스쿼트',
  date: DateTime.utc(2026, 10, day),
  status: status,
  sets: 2,
  volume: volume,
  startedAt: DateTime.utc(2026, 10, day, 10),
  seconds: 612,
);

class FakeWorkoutHistory extends FakeHomeServer {
  FakeWorkoutHistory() : super(FakeHomeRoutines());
  List<ServerWorkoutRecord> recordsData = [
    historyRecord(87),
    historyRecord(88, status: 'aborted'),
    historyRecord(89, status: 'in_progress'),
  ];
  final requests = <(DateTime, DateTime, int, String?)>[];
  Future<ServerWorkoutPage> Function(DateTime, DateTime, int, String?)? handler;
  int pageSize = 50;
  @override
  Future<ServerWorkoutPage> records(
    DateTime a,
    DateTime b, {
    int page = 1,
    String? status,
  }) async {
    requests.add((a, b, page, status));
    if (handler != null) return handler!(a, b, page, status);
    if (error != null) throw error!;
    final all = recordsData
        .where(
          (e) =>
              !e.date.isBefore(routineDate(a)) &&
              !e.date.isAfter(routineDate(b)),
        )
        .toList();
    final complete = all.where((e) => e.status == 'completed').toList();
    final filtered = all
        .where((e) => status == null || e.status == status)
        .toList();
    return ServerWorkoutPage(
      items: filtered.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      total: filtered.length,
      count: complete.length,
      sets: complete.fold(0, (v, e) => v + e.sets),
      volume: complete.fold<num>(0, (v, e) => v + e.volume),
      seconds: complete.length * 612,
      dates: complete.map((e) => routineDateKey(e.date)).toSet(),
    );
  }
}

class FakeWorkoutRecordRepository extends FakeWorkoutRepository {
  FakeWorkoutRecordRepository() {
    data = workoutJson(
      status: 'completed',
      sets: [
        {
          'set_id': 1,
          'client_set_id': 'one',
          'set_no': 1,
          'version': 1,
          'weight_kg': 60,
          'reps': 10,
          'rest_sec': null,
          'is_done': true,
        },
        {
          'set_id': 3,
          'client_set_id': 'three',
          'set_no': 3,
          'version': 1,
          'weight_kg': 20,
          'reps': 8,
          'rest_sec': 90,
          'is_done': true,
        },
      ],
    );
    data['started_at'] = '2026-10-26T10:00:00Z';
    data.addAll({
      'duration_sec': 612,
      'completed_at': '2026-10-26T10:10:12Z',
      'memo': '기록 메모',
    });
  }
  bool removed = false;
  Object? lookupError;
  void Function()? onCancel;
  @override
  Future<WorkoutLog> detail(int id) async {
    if (lookupError != null) throw lookupError!;
    if (removed) {
      throw ApiRequestError(
        const ApiFailure(
          code: 'NOT_FOUND',
          message: '찾을 수 없어요.',
          status: 404,
          fields: null,
        ),
      );
    }
    final done = (data['sets'] as List).where((e) => e['is_done'] == true);
    data['set_count'] = done.length;
    data['total_volume_kg'] = done.fold<num>(
      0,
      (v, e) => v + (e['weight_kg'] as num) * (e['reps'] as int),
    );
    return super.detail(id);
  }

  @override
  Future<void> cancel(int id) async {
    await super.cancel(id);
    removed = true;
    onCancel?.call();
  }
}
