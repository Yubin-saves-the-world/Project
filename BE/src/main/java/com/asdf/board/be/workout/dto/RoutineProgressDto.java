package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record RoutineProgressDto(
        @Schema(description = "완료한 종목 수") Integer done,
        @Schema(description = "루틴 전체 종목 수") Integer total
) {
}
