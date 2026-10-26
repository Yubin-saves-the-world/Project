package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record AnalysisSummaryDto(
        @Schema(description = "분석 ID") Long analysisId,
        @Schema(description = "진행 상태") String status,
        @Schema(description = "분석 방식") String source,
        @Schema(description = "종합 균형 점수. 산식 검증 전에는 null") Integer balanceScore,
        @Schema(description = "체형 유형. 분류 기준 검증 전에는 null") String bodyType,
        @Schema(description = "비교에 쓴 목표 체형") Long goalBodyId,
        @Schema(description = "접수 시각") OffsetDateTime createdAt
) {
}
