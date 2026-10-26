package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record WorkoutStartedDto(
        @Schema(description = "운동 기록 ID") Long logId,
        @Schema(description = "종목") Long exerciseId,
        @Schema(description = "루틴 ID") Long routineId,
        @Schema(description = "서버 기록 시작 시각. 앱을 나갔다 오면 지금−started_at으로 경과 시간을 복구") OffsetDateTime startedAt,
        @Schema(description = "항상 in_progress") String status,
        @Schema(description = "이미 진행 중인 기록을 반환한 경우 true") Boolean resumed
) {
}
