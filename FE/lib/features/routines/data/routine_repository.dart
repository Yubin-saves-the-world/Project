import 'models/routine.dart';

abstract interface class RoutineRepository {
  Future<RecommendedRoutineWeek> weekly(DateTime monday);
  Future<RecommendedRoutine> detail(int id);
  Future<RecommendedRoutine> setStatus(int id, RoutineStatus status);
}
