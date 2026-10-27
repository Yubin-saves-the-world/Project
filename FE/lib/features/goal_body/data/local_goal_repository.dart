import 'dart:typed_data';
import '../../body_analysis/data/models/body_analysis.dart';
import '../../photos/data/models/body_photo.dart';
import '../../photos/data/photo_repository.dart';
import 'goal_repository.dart';
import 'models/goal_body.dart';

/// 계정별 앱 세션의 목표 사진·설명. 실제 특징 추출 결과를 생성하지 않는다.
class LocalGoalRepository implements GoalRepository {
  LocalGoalRepository({this.photos});
  final PhotoRepository? photos;
  GoalBody? _goal;
  int _nextId = 1;
  @override
  Future<GoalBody?> load() async => _goal;
  Future<GoalBody> _save(int id, int? photoId, String? description) async {
    Uint8List? preview;
    if (photoId != null) {
      final items = await photos?.list(type: BodyPhotoType.goal);
      final selected = items?.items.where((p) => p.id == photoId).firstOrNull;
      if (selected?.previewBytes == null) {
        throw StateError('목표 사진을 다시 선택해 주세요.');
      }
      preview = Uint8List.fromList(selected!.previewBytes!);
    }
    if (preview == null &&
        (description == null || description.trim().isEmpty)) {
      throw StateError('사진을 추가하거나 목표를 설명해 주세요.');
    }
    // 앱 세션에 등록한 상태다. AI 측정값·특징 요약을 만들어 넣지 않는다.
    final next = GoalBody(
      id: id,
      status: AnalysisStatus.done,
      createdAt: _goal?.createdAt ?? DateTime.now(),
      description: description,
      previewBytes: preview,
    );
    if (photoId != null) await photos!.delete(photoId);
    return _goal = next;
  }

  @override
  Future<GoalBody> create({int? photoId, String? description}) async {
    if (_goal != null) throw StateError('이미 등록한 목표가 있어요.');
    return _save(_nextId++, photoId, description);
  }

  @override
  Future<GoalBody> update(int id, {int? photoId, String? description}) async {
    if (_goal?.id != id) throw StateError('목표를 다시 불러와 주세요.');
    // 설명만 변경할 때도 이미 등록한 로컬 사진을 유지한다.
    if (photoId == null && _goal!.previewBytes != null) {
      return _goal = GoalBody(
        id: id,
        status: AnalysisStatus.done,
        createdAt: _goal!.createdAt,
        description: description,
        previewBytes: _goal!.previewBytes,
      );
    }
    return _save(id, photoId, description);
  }

  @override
  Future<void> delete(int id) async {
    if (_goal?.id != id) throw StateError('목표를 다시 불러와 주세요.');
    _goal = null;
  }
}
