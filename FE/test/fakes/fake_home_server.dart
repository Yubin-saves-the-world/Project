import 'package:fe/features/home/data/home_server_repository.dart';
import 'package:fe/features/home/data/recommendation_choice_store.dart';
import 'package:fe/features/home/data/models/server_home_data.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'package:fe/features/routines/data/routine_repository.dart';
import 'fake_routine_repository.dart';

class FakeChoiceStore implements RecommendationChoiceStore {
  Map<String, int> choices = {};
  Object? readError, writeError;
  @override
  Future<Map<String, int>> read() async {
    if (readError != null) throw readError!;
    return {...choices};
  }

  @override
  Future<void> write(Map<String, int> value) async {
    if (writeError != null) throw writeError!;
    choices = {...value};
  }
}

class FakeHomeRoutines implements RoutineRepository {
  final data = <int, RecommendedRoutine>{
    44: routineFixture(date: DateTime(2026, 10, 26)),
  };
  final patches = <(int, RoutineStatus)>[];
  bool failRestore = false, failSkip = false;
  @override
  Future<RecommendedRoutine> detail(int id) async => data[id]!;
  @override
  Future<RecommendedRoutine> setStatus(int id, RoutineStatus status) async {
    patches.add((id, status));
    if ((status == RoutineStatus.planned && failRestore) ||
        (status == RoutineStatus.skipped && failSkip)) {
      throw StateError('동기화 실패');
    }
    return data[id] = routineFixture(status: status, date: data[id]!.date);
  }

  @override
  Future<RecommendedRoutineWeek> weekly(DateTime monday) async =>
      RecommendedRoutineWeek(monday, [
        for (var i = 0; i < 7; i++) _day(monday.add(Duration(days: i))),
      ]);
  RecommendedRoutineDay _day(DateTime date) {
    final value = data.values
        .where((r) => routineDateKey(r.date) == routineDateKey(date))
        .firstOrNull;
    return RecommendedRoutineDay(
      date,
      value == null,
      value == null
          ? null
          : RecommendedRoutineSummary(
              id: value.id,
              title: value.title,
              part: value.part,
              minutes: value.minutes,
              status: value.status,
              itemCount: value.items.length,
              doneCount: value.items.where((i) => i.done).length,
            ),
    );
  }
}

class FakeHomeServer implements HomeServerRepository {
  FakeHomeServer(this.routines);
  final FakeHomeRoutines routines;
  DateTime todayDate = DateTime(2026, 10, 26);
  Object? error;
  int analyses = 1;
  List<ServerWorkoutRecord> completed = [];
  List<ServerWorkoutRecord> running = [];
  Future<ServerWorkoutPage> Function(DateTime, DateTime, int)? onRecords;
  @override
  Future<RecommendedRoutine?> today() async {
    if (error != null) throw error!;
    return routines.data.values
        .where((r) => routineDateKey(r.date) == routineDateKey(todayDate))
        .firstOrNull;
  }

  @override
  Future<ServerWorkoutPage> records(
    DateTime start,
    DateTime end, {
    int page = 1,
    String? status,
  }) async {
    if (error != null) throw error!;
    if (onRecords != null) return onRecords!(start, end, page);
    final records = completed
        .where(
          (r) =>
              !routineDate(r.date).isBefore(routineDate(start)) &&
              !routineDate(r.date).isAfter(routineDate(end)),
        )
        .toList();
    return serverWorkoutPage(records, page: page);
  }

  @override
  Future<List<ServerWorkoutRecord>> active(DateTime today) async {
    if (error != null) throw error!;
    return running;
  }

  @override
  Future<int> analysisCount() async {
    if (error != null) throw error!;
    return analyses;
  }
}

ServerWorkoutPage serverWorkoutPage(
  List<ServerWorkoutRecord> records, {
  int page = 1,
}) => ServerWorkoutPage(
  items: records.skip((page - 1) * 50).take(50).toList(),
  page: page,
  total: records.length,
  count: records.length,
  sets: records.fold(0, (v, r) => v + r.sets),
  volume: records.fold<num>(0, (v, r) => v + r.volume),
  dates: records.map((r) => routineDateKey(r.date)).toSet(),
);
ServerWorkoutRecord serverWorkout(
  int id, {
  String status = 'completed',
  int sets = 3,
  num volume = 1200,
}) => ServerWorkoutRecord(
  id: id,
  exerciseId: 12,
  name: '바벨 스쿼트',
  date: DateTime(2026, 10, 26),
  status: status,
  sets: sets,
  volume: volume,
  startedAt: DateTime.utc(2026, 10, 26, 4),
);
