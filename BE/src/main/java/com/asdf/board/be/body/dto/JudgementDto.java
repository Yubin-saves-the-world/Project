package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

public record JudgementDto(
        @Schema(description = "판정 항목") String item,
        @Schema(description = "화면 표시 이름") String label,
        @Schema(description = "측정값. 측정하지 못했으면 null") BigDecimal value,
        @Schema(description = "단위") String unit,
        @Schema(description = "good 양호 / caution 주의 / unavailable 평가 불가(측정 못 했거나 판정 기준이 검증되기 전)") String level,
        @Schema(description = "level=unavailable일 때 사유") String reason
) {
}
