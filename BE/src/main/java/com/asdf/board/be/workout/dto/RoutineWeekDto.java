package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import java.util.List;

public record RoutineWeekDto(
        @Schema(description = "그 주 월요일") LocalDate weekStart,
        @Schema(description = "월~일 7개") List<RoutineDayDto> days
) {
}
