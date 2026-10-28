import 'package:fe/features/body_analysis/data/analysis_repository.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';

class FakeAnalysisRepository implements AnalysisRepository {
  int starts = 0, details = 0, generated = 0;
  int? front, side, goalId, generatedId;
  Object? startError, detailError, historyError;
  BodyAnalysis response = result(AnalysisStatus.pending);
  Future<BodyAnalysis> Function()? onDetail;
  AnalysisUsage? currentUsage;
  AnalysisGoal? currentGoal;
  List<AnalysisSummary> records = [];
  @override
  @override
  Future<AnalysisTicket> startText({
    required String text,
    int? goalId,
  }) async {
    starts++;
    if (startError != null) throw startError!;
    return const AnalysisTicket(31);
  }

  Future<AnalysisTicket> start({
    required int photoId,
    int? sidePhotoId,
    int? goalId,
  }) async {
    starts++;
    front = photoId;
    side = sidePhotoId;
    this.goalId = goalId;
    if (startError != null) throw startError!;
    return const AnalysisTicket(31);
  }

  @override
  Future<BodyAnalysis> detail(int id) async {
    details++;
    if (detailError != null) throw detailError!;
    if (onDetail != null) return onDetail!();
    return response;
  }

  @override
  Future<AnalysisPageData> history({int page = 1}) async {
    if (historyError != null) throw historyError!;
    return AnalysisPageData(records, page, records.length);
  }

  @override
  Future<AnalysisUsage?> usage() async => currentUsage;
  @override
  Future<AnalysisGoal?> goal() async => currentGoal;
  @override
  Future<List<AnalysisRoutine>> generateRoutines(int analysisId) async {
    generated++;
    generatedId = analysisId;
    return [
      const AnalysisRoutine(
        title: '상체 균형',
        date: '2026-10-27',
        id: 4,
        items: ['로우'],
      ),
    ];
  }
}

BodyAnalysis result(AnalysisStatus status, {num? score}) => BodyAnalysis(
  id: 31,
  status: status,
  createdAt: DateTime(2026, 10, 26),
  score: score,
  measures: const {'shoulder_tilt_deg': 2.5, 'neck_forward_deg': null},
  unavailable: const {'neck_forward': 'SIDE_PHOTO_MISSING'},
);
