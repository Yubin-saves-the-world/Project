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
      throw StateError('추천 루틴을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
  @override
  Future<RecommendedRoutine> setStatus(int id, RoutineStatus status) async =>
      throw StateError('루틴을 변경하지 못했어요. 잠시 후 다시 시도해 주세요.');
}
