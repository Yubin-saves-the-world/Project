package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;

public record RoutineDayDto(
        @Schema(description = "날짜") LocalDate date,
        @Schema(description = "휴식일 여부") Boolean isRestDay,
        @Schema(description = "루틴 요약. 휴식일이면 null") RoutineSummaryDto routine
) {
}
