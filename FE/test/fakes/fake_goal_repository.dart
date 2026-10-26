import 'package:fe/features/goal_body/data/goal_repository.dart';
import 'package:fe/features/goal_body/data/models/goal_body.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';

GoalBody goalFixture({
  AnalysisStatus status = AnalysisStatus.done,
  String? description = '균형 잡힌 어깨',
}) => GoalBody(
  id: 7,
  status: status,
  createdAt: DateTime(2026, 10, 26),
  description: description,
  summary: status == AnalysisStatus.done ? '어깨와 등 근육 발달' : null,
  errorMessage: status == AnalysisStatus.failed ? '사진이 흐려요.' : null,
);

class FakeGoalRepository implements GoalRepository {
  GoalBody? goal;
  Object? loadError, saveError, deleteError;
  Future<GoalBody?> Function()? onLoad;
  int creates = 0, updates = 0, deletes = 0, loads = 0;
  int? photoId;
  String? description;
  @override
  Future<GoalBody?> load() async {
    loads++;
    if (loadError != null) throw loadError!;
    return onLoad == null ? goal : await onLoad!();
  }

  @override
  Future<GoalBody> create({int? photoId, String? description}) async {
    creates++;
    this.photoId = photoId;
    this.description = description;
    if (saveError != null) throw saveError!;
    return goal = goalFixture(
      status: photoId == null ? AnalysisStatus.done : AnalysisStatus.pending,
      description: description,
    );
  }

  @override
  Future<GoalBody> update(int id, {int? photoId, String? description}) async {
    updates++;
    this.photoId = photoId;
    this.description = description;
    if (saveError != null) throw saveError!;
    return goal = goalFixture(
      status: photoId == null ? AnalysisStatus.done : AnalysisStatus.pending,
      description: description,
    );
  }

  @override
  Future<void> delete(int id) async {
    deletes++;
    if (deleteError != null) throw deleteError!;
    goal = null;
  }
}
