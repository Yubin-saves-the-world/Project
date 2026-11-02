import 'analysis_repository.dart';
import 'models/body_analysis.dart';

/// 미리보기에서는 분석 수치·진행 기록을 만들어 내지 않는다.
class LocalAnalysisRepository
    implements AnalysisRepository, TextAnalysisRepository {
  Never _unavailable() => throw StateError('분석을 시작할 수 없어요. 잠시 후 다시 시도해 주세요.');
  @override
  Future<AnalysisTicket> startText(String text) async => _unavailable();
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
