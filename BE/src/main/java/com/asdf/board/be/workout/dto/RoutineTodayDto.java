package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;

public record RoutineTodayDto(
        @Schema(description = "조회한 날짜") LocalDate date,
        @Schema(description = "그날 루틴이 없으면 true") Boolean isRestDay,
        @Schema(description = "루틴. 휴식일이면 null") RoutineDto routine
) {
}
