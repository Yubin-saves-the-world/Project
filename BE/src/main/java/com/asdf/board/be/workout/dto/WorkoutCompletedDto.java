package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record WorkoutCompletedDto(
        @Schema(description = "운동 기록 ID") Long logId,
        @Schema(description = "종료 시각") OffsetDateTime completedAt,
        @Schema(description = "확정된 소요 시간(초)") Integer durationSec,
        @Schema(description = "이 종목 총 볼륨") BigDecimal totalVolumeKg,
        @Schema(description = "완료 세트 수") Integer setCount,
        @Schema(description = "루틴에서 시작한 경우 진행률. 자유 운동이면 null") RoutineProgressDto routineProgress,
        @Schema(description = "루틴 상태. 자유 운동이면 null. 모든 종목을 끝내면 done으로 바뀜") String routineStatus
) {
}
