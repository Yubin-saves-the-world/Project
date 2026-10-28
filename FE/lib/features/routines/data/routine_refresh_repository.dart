abstract interface class RoutineRefreshRepository {
  Future<void> regenerate();
}

class LocalRoutineRefreshRepository implements RoutineRefreshRepository {
  @override
  Future<void> regenerate() async {
    throw StateError('완료된 체형 분석이 필요해요. 분석을 마친 뒤 추천 루틴을 만들어 주세요.');
  }
}
