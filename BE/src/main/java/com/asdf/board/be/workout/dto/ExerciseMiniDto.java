package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record ExerciseMiniDto(
        @Schema(description = "운동 ID") Long exerciseId,
        @Schema(description = "이름") String name,
        @Schema(description = "주 부위") String targetPart
) {
}
