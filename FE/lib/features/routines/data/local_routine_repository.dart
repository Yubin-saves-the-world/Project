import 'models/routine.dart';
import 'routine_repository.dart';

/// 서버 추천을 임의로 생성하지 않는 로컬 미리보기.
class LocalRoutineRepository implements RoutineRepository {
  @override
  Future<RecommendedRoutineWeek> weekly(DateTime monday) async =>
      RecommendedRoutineWeek(monday, [
        for (var i = 0; i < 7; i++)
          RecommendedRoutineDay(monday.add(Duration(days: i)), true, null),
      ]);
  @override
  Future<RecommendedRoutine> detail(int id) async =>
      throw StateError('추천 루틴은 서버 연결 후 확인할 수 있어요.');
  @override
  Future<RecommendedRoutine> setStatus(int id, RoutineStatus status) async =>
      throw StateError('추천 루틴은 서버 연결 후 변경할 수 있어요.');
}
