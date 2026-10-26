package com.asdf.board.be.coach.dto;

import com.asdf.board.be.workout.dto.RoutineDto;
import io.swagger.v3.oas.annotations.media.Schema;

public record SuggestionConfirmedDto(
        Long suggestionId,
        @Schema(description = "applied / dismissed") String status,
        @Schema(description = "적용 후 루틴. 거절했으면 null") RoutineDto routine
) {
}
