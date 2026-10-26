package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import java.util.List;

public record AnalysisDto(
        @Schema(description = "분석 ID") Long analysisId,
        @Schema(description = "진행 상태") String status,
        @Schema(description = "사진 분석 / 글 분석") String source,
        @Schema(description = "status=failed일 때만 값이 있음") String errorCode,
        @Schema(description = "status=failed일 때 사용자에게 보여줄 문장") String errorMessage,
        @Schema(description = "정면 사진 ID. 사진을 삭제했으면 null. 글 분석이면 null") Long photoId,
        @Schema(description = "측면 사진 ID. 없으면 null") Long sidePhotoId,
        @Schema(description = "비교에 쓴 목표 체형. 없으면 null") Long goalBodyId,
        @Schema(description = "status=done이고 source=photo일 때만 값이 있음") MeasuresDto measures,
        @Schema(description = "종합 균형 점수. status=done이고 **점수 산식이 검증된 뒤에만** 값이 있고, 그 전에는 null (0점이 아님). 앱은 null이면 \"점수 산출 불가\"로 표시") Integer balanceScore,
        @Schema(description = "측정·판정 기준 버전. 버전이 다르면 수치 변화를 직접 비교하지 않는다") String measurementVersion,
        @Schema(description = "골격 비율 기준 체형 유형. status=done이고 source=photo일 때만이고, **체형 분류 기준이 검증되기 전에는 null**") String bodyType,
        @Schema(description = "항목별 판정. status=done이고 source=photo일 때만 채워지고 아니면 빈 배열") List<JudgementDto> judgements,
        @Schema(description = "목표 체형(goal_body_id)이 있고 status=done일 때만 값이 있음") GoalComparisonDto goalComparison,
        @Schema(description = "source=text일 때 AI가 정리한 요약") String textSummary,
        @Schema(description = "접수 시각") OffsetDateTime createdAt,
        @Schema(description = "완료·실패 시각") OffsetDateTime completedAt
) {
}
