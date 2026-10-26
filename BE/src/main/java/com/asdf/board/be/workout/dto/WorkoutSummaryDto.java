package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record WorkoutSummaryDto(
        @Schema(description = "종료된 기록 수") Integer logCount,
        @Schema(description = "운동한 날 수") Integer workoutDays,
        @Schema(description = "완료 세트 합") Integer totalSets,
        @Schema(description = "총 볼륨") BigDecimal totalVolumeKg,
        @Schema(description = "총 운동 시간(초)") Integer totalDurationSec,
        @Schema(description = "운동한 날짜 목록 (달력 표시용)") List<LocalDate> workoutDates
) {
}
