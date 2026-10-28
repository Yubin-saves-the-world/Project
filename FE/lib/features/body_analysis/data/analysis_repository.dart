import 'models/body_analysis.dart';

class AnalysisRoutine {
  const AnalysisRoutine({
    required this.title,
    required this.date,
    required this.id,
    required this.items,
  });
  final String title, date;
  final int id;
  final List<String> items;
  factory AnalysisRoutine.fromJson(Map<String, dynamic> json) =>
      AnalysisRoutine(
        title: json['title'] as String,
        date: json['scheduled_date'] as String,
        id: json['routine_id'] as int,
        items: List.unmodifiable(
          (json['items'] as List? ?? []).map(
            (v) => (v as Map)['exercise']['name'] as String,
          ),
        ),
      );
}

abstract interface class AnalysisRepository {
  Future<AnalysisTicket> start({
    required int photoId,
    int? sidePhotoId,
    int? goalId,
  });
  Future<AnalysisTicket> startText({
    required String text,
    int? goalId,
  });
  Future<BodyAnalysis> detail(int id);
  Future<AnalysisPageData> history({int page = 1});
  Future<AnalysisUsage?> usage();
  Future<AnalysisGoal?> goal();
  Future<List<AnalysisRoutine>> generateRoutines(int analysisId);
}
