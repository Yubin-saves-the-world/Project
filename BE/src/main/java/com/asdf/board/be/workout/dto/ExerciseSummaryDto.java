package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record ExerciseSummaryDto(
        @Schema(description = "운동 ID") Long exerciseId,
        @Schema(description = "이름") String name,
        @Schema(description = "주 운동 부위") String targetPart,
        @Schema(description = "기구") String equipment,
        @Schema(description = "난이도 1(쉬움)~5") Integer difficulty,
        @Schema(description = "권장 최소 세트") Integer minSets,
        @Schema(description = "권장 최대 세트") Integer maxSets,
        @Schema(description = "시범 영상 URL. 없으면 null") String mediaUrl
) {
}
