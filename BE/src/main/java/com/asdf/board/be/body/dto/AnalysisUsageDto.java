package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record AnalysisUsageDto(
        @Schema(description = "오늘 사용한 횟수 (done·pending 집계)") Integer used,
        @Schema(description = "하루 한도") Integer limit,
        @Schema(description = "남은 횟수") Integer remaining,
        @Schema(description = "다음 초기화 시각 (KST 자정)") OffsetDateTime resetAt
) {
}
