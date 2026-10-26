package com.asdf.board.be.coach.dto;

import com.asdf.board.be.workout.dto.ExerciseSummaryDto;
import io.swagger.v3.oas.annotations.media.Schema;

public record SuggestionChangeDto(
        @Schema(description = "교체 / 추가 / 제거") String action,
        @Schema(description = "교체·제거 대상 루틴 종목. add면 null") Long routineItemId,
        @Schema(description = "새로 넣을 종목. remove면 null") ExerciseSummaryDto exercise,
        @Schema(description = "목표 세트. remove면 null") Integer targetSets,
        @Schema(description = "목표 횟수. remove면 null") Integer targetReps
) {
}
