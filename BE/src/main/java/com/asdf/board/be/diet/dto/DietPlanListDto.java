package com.asdf.board.be.diet.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record DietPlanListDto(
        @Schema(description = "근거 분석") Long analysisId,
        @Schema(description = "오늘부터 7일치") List<DietPlanDto> plans
) {
}
