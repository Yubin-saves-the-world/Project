enum AnalysisStatus { pending, done, failed, unknown }

AnalysisStatus analysisStatus(Object? value) => AnalysisStatus.values
    .firstWhere((s) => s.name == value, orElse: () => AnalysisStatus.unknown);

class AnalysisTicket {
  const AnalysisTicket(this.id);
  final int id;
  factory AnalysisTicket.fromJson(Map<String, dynamic> json) =>
      AnalysisTicket(json['analysis_id'] as int);
}

class AnalysisSummary {
  const AnalysisSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.score,
    this.bodyType,
  });
  final int id;
  final AnalysisStatus status;
  final DateTime createdAt;
  final num? score;
  final String? bodyType;
  factory AnalysisSummary.fromJson(Map<String, dynamic> json) =>
      AnalysisSummary(
        id: json['analysis_id'] as int,
        status: analysisStatus(json['status']),
        createdAt: DateTime.parse(json['created_at'] as String),
        score: json['balance_score'] as num?,
        bodyType: json['body_type'] as String?,
      );
}

class AnalysisPageData {
  AnalysisPageData(List<AnalysisSummary> items, this.page, this.total)
    : items = List.unmodifiable(items);
  final List<AnalysisSummary> items;
  final int page, total;
  factory AnalysisPageData.fromJson(Map<String, dynamic> json) =>
      AnalysisPageData(
        (json['items'] as List)
            .map(
              (v) =>
                  AnalysisSummary.fromJson(Map<String, dynamic>.from(v as Map)),
            )
            .toList(),
        json['page'] as int,
        json['total'] as int,
      );
}

class AnalysisUsage {
  const AnalysisUsage({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.resetAt,
  });
  final int used, limit, remaining;
  final DateTime resetAt;
  factory AnalysisUsage.fromJson(Map<String, dynamic> json) => AnalysisUsage(
    used: json['used'] as int,
    limit: json['limit'] as int,
    remaining: json['remaining'] as int,
    resetAt: DateTime.parse(json['reset_at'] as String),
  );
}

class AnalysisGoal {
  const AnalysisGoal(this.id, this.status, this.summary);
  final int id;
  final AnalysisStatus status;
  final String? summary;
  factory AnalysisGoal.fromJson(Map<String, dynamic> json) => AnalysisGoal(
    json['goal_body_id'] as int,
    analysisStatus(json['status']),
    (json['summary'] ?? json['description']) as String?,
  );
}

class AnalysisJudgement {
  const AnalysisJudgement({
    required this.label,
    required this.level,
    this.value,
    this.unit,
    this.reason,
  });
  final String label, level;
  final num? value;
  final String? unit, reason;
  factory AnalysisJudgement.fromJson(Map<String, dynamic> json) =>
      AnalysisJudgement(
        label: json['label'] as String,
        level: json['level'] is String ? json['level'] as String : 'unknown',
        value: json['value'] as num?,
        unit: json['unit'] as String?,
        reason: json['reason'] as String?,
      );
}

class AnalysisComparison {
  AnalysisComparison({
    required this.summary,
    required this.detail,
    required List<String> parts,
  }) : parts = List.unmodifiable(parts);
  final String summary, detail;
  final List<String> parts;
  factory AnalysisComparison.fromJson(Map<String, dynamic> json) =>
      AnalysisComparison(
        summary: json['summary'] as String,
        detail: json['detail'] as String,
        parts: (json['priority_parts'] as List)
            .map((p) => (p as Map)['label'] as String)
            .toList(),
      );
}

class BodyAnalysis {
  BodyAnalysis({
    required this.id,
    required this.status,
    required this.createdAt,
    this.score,
    this.bodyType,
    this.errorCode,
    this.errorMessage,
    this.measurementVersion,
    Map<String, num?> measures = const {},
    Map<String, String> unavailable = const {},
    List<AnalysisJudgement> judgements = const [],
    this.comparison,
  }) : measures = Map.unmodifiable(measures),
       unavailable = Map.unmodifiable(unavailable),
       judgements = List.unmodifiable(judgements);
  final int id;
  final AnalysisStatus status;
  final DateTime createdAt;
  final num? score;
  final String? bodyType, errorCode, errorMessage, measurementVersion;
  final Map<String, num?> measures;
  final Map<String, String> unavailable;
  final List<AnalysisJudgement> judgements;
  final AnalysisComparison? comparison;
  factory BodyAnalysis.fromJson(Map<String, dynamic> json) {
    final measures = json['measures'] as Map?;
    return BodyAnalysis(
      id: json['analysis_id'] as int,
      status: analysisStatus(json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      score: json['balance_score'] as num?,
      bodyType: json['body_type'] as String?,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      measurementVersion: json['measurement_version'] as String?,
      measures: {
        for (final key in [
          'shoulder_tilt_deg',
          'pelvis_tilt_deg',
          'neck_forward_deg',
          'shoulder_hip_ratio',
          'torso_leg_ratio',
        ])
          key: measures?[key] as num?,
      },
      unavailable: {
        for (final item in (measures?['unavailable'] as List? ?? []))
          (item as Map)['key'] as String: item['reason'] as String,
      },
      judgements: (json['judgements'] as List? ?? [])
          .map(
            (v) =>
                AnalysisJudgement.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
      comparison: json['goal_comparison'] is Map
          ? AnalysisComparison.fromJson(
              Map<String, dynamic>.from(json['goal_comparison'] as Map),
            )
          : null,
    );
  }
}

String analysisFailureMessage(String? code, String? fallback) => switch (code) {
  'IMAGE_BLURRY' => '사진이 흐려요. 밝은 곳에서 다시 촬영해 주세요.',
  'NO_PERSON' || 'NOT_FULL_BODY' => '머리부터 발끝까지 전신이 나오게 촬영해 주세요.',
  'MULTIPLE_PEOPLE' => '사진에 한 명만 나오게 촬영해 주세요.',
  'NOT_FRONTAL' => '정면으로 서서 촬영해 주세요.',
  'AI_FAILED' || 'AI_TIMEOUT' => '분석을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.',
  _ => fallback ?? '분석을 완료하지 못했어요. 다시 시도해 주세요.',
};
String measurementReason(String? reason) => switch (reason) {
  'SIDE_PHOTO_MISSING' => '측면 사진이 없어 측정하지 못했어요.',
  'OCCLUDED' => '신체가 가려져 측정하지 못했어요.',
  'LOW_CONFIDENCE' => '사진에서 정확한 위치를 확인하지 못했어요.',
  'PROFILE_NOT_VALIDATED' => '판정 기준을 확인하는 중이에요.',
  _ => '측정하지 못했어요.',
};
