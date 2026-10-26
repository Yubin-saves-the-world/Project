import 'analysis_repository.dart';
import 'models/body_analysis.dart';

/// 미리보기에서는 분석 수치·진행 기록을 만들어 내지 않는다.
class LocalAnalysisRepository implements AnalysisRepository {
  Never _unavailable() =>
      throw StateError('로컬 미리보기에서는 체형 분석을 제공하지 않아요. 서버 연결 후 이용해 주세요.');
  @override
  Future<AnalysisTicket> start({
    required int photoId,
    int? sidePhotoId,
    int? goalId,
  }) async => _unavailable();
  @override
  Future<BodyAnalysis> detail(int id) async => _unavailable();
  @override
  Future<AnalysisPageData> history({int page = 1}) async =>
      AnalysisPageData([], page, 0);
  @override
  Future<AnalysisUsage?> usage() async => null;
  @override
  Future<AnalysisGoal?> goal() async => null;
  @override
  Future<List<AnalysisRoutine>> generateRoutines(int analysisId) async =>
      _unavailable();
}
