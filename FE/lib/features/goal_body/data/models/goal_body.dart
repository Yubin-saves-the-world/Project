import '../../../body_analysis/data/models/body_analysis.dart';

class GoalBody {
  const GoalBody({
    required this.id,
    required this.status,
    required this.createdAt,
    this.summary,
    this.description,
    this.errorMessage,
  });
  final int id;
  final AnalysisStatus status;
  final DateTime createdAt;
  final String? summary, description, errorMessage;
  AnalysisGoal get comparison =>
      AnalysisGoal(id, status, summary ?? description);
  factory GoalBody.fromJson(Map<String, dynamic> json) => GoalBody(
    id: json['goal_body_id'] as int,
    status: analysisStatus(json['status']),
    createdAt: DateTime.parse(json['created_at'] as String),
    summary: json['summary'] as String?,
    description: json['description'] as String?,
    errorMessage: json['error_message'] as String?,
  );
}
