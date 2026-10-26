package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record AnalysisAcceptedDto(
        @Schema(description = "분석 ID. GET /body-analyses/{analysis_id}로 결과를 확인") Long analysisId,
        @Schema(description = "항상 pending") String status,
        @Schema(description = "다음 조회까지 권장 대기(ms)") Integer pollAfterMs,
        @Schema(description = "접수 시각") OffsetDateTime createdAt
) {
}
