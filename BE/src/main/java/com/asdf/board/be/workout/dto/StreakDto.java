package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;

public record StreakDto(
        @Schema(description = "현재 연속 운동일 (오늘 또는 어제까지 이어진 일수)") Integer currentStreak,
        @Schema(description = "최장 연속 운동일") Integer longestStreak,
        @Schema(description = "마지막 운동 날짜. 기록이 없으면 null") LocalDate lastWorkoutDate
) {
}
