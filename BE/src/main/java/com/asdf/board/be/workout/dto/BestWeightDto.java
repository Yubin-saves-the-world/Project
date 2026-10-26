package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

public record BestWeightDto(
        @Schema(description = "운동 ID") Long exerciseId,
        @Schema(description = "이름") String name,
        @Schema(description = "완료 세트 중 최고 무게") BigDecimal maxWeightKg
) {
}
