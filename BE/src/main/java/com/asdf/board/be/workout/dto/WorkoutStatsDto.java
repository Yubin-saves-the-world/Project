package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.util.List;

public record WorkoutStatsDto(
        @Schema(description = "운동한 날 수") Integer workoutDays,
        @Schema(description = "종료된 기록 수") Integer logCount,
        @Schema(description = "총 볼륨") BigDecimal totalVolumeKg,
        @Schema(description = "날짜별 볼륨 (날짜 오름차순)") List<VolumePointDto> volumeTrend,
        @Schema(description = "부위별 횟수") List<PartCountDto> byPart,
        @Schema(description = "종목별 최고 무게") List<BestWeightDto> bestWeights
) {
}
