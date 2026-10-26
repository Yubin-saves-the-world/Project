import '../../body_analysis/data/models/body_analysis.dart';
import 'goal_repository.dart';
import 'models/goal_body.dart';

/// 설명만 앱 세션에 저장하는 계정별 미리보기. 사진 분석 결과를 만들지 않는다.
class LocalGoalRepository implements GoalRepository {
  GoalBody? _goal;
  int _nextId = 1;
  @override
  Future<GoalBody?> load() async => _goal;
  GoalBody _save(int id, int? photoId, String? description) {
    if (photoId != null) throw StateError('사진 목표는 서버 연결 후 이용할 수 있어요.');
    if (description == null || description.trim().isEmpty) {
      throw StateError('목표를 설명해 주세요.');
    }
    return _goal = GoalBody(
      id: id,
      status: AnalysisStatus.done,
      createdAt: _goal?.createdAt ?? DateTime.now(),
      description: description,
    );
  }

  @override
  Future<GoalBody> create({int? photoId, String? description}) async {
    if (_goal != null) throw StateError('이미 등록한 목표가 있어요.');
    return _save(_nextId++, photoId, description);
  }

  @override
  Future<GoalBody> update(int id, {int? photoId, String? description}) async {
    if (_goal?.id != id) throw StateError('목표를 다시 불러와 주세요.');
    return _save(id, photoId, description);
  }

  @override
  Future<void> delete(int id) async {
    if (_goal?.id != id) throw StateError('목표를 다시 불러와 주세요.');
    _goal = null;
  }
}
