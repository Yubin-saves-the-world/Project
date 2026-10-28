import 'models/goal_body.dart';

abstract interface class GoalRepository {
  Future<GoalBody?> load();
  Future<GoalBody> create({int? photoId, String? description});
  Future<GoalBody> update(int id, {int? photoId, String? description});
  Future<void> delete(int id);
}
