import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import 'models/routine.dart';
import 'routine_repository.dart';

class ServerRoutineRepository implements RoutineRepository {
  ServerRoutineRepository(this.api);
  final ApiClient api;
  @override
  Future<RecommendedRoutineWeek> weekly(DateTime monday) async {
    if (monday.weekday != DateTime.monday) throw ArgumentError('월요일 날짜가 필요해요.');
    final date = routineDateKey(monday);
    final result = RecommendedRoutineWeek.fromJson(
      (await api.send(
        'GET',
        Uri(
          path: ApiContract.weeklyRoutines,
          queryParameters: {'week_start': date},
        ).toString(),
      ))!,
    );
    if (routineDateKey(result.start) != date) {
      throw StateError('다른 주의 루틴을 받았어요. 다시 확인해 주세요.');
    }
    return result;
  }

  @override
  Future<RecommendedRoutine> detail(int id) async =>
      RecommendedRoutine.fromJson(
        (await api.send('GET', ApiContract.routine(id)))!,
      );
  @override
  Future<RecommendedRoutine> setStatus(int id, RoutineStatus status) async {
    if (status != RoutineStatus.planned && status != RoutineStatus.skipped) {
      throw ArgumentError('건너뛰기 또는 되돌리기만 할 수 있어요.');
    }
    return RecommendedRoutine.fromJson(
      (await api.send(
        'PATCH',
        ApiContract.routine(id),
        body: {'status': status.name},
      ))!,
    );
  }
}
