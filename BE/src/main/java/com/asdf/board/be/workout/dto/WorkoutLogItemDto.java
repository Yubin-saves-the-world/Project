package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

public record WorkoutLogItemDto(
        @Schema(description = "운동 기록 ID") Long logId,
        @Schema(description = "종목") ExerciseMiniDto exercise,
        @Schema(description = "루틴에서 시작했으면 루틴 ID") Long routineId,
        @Schema(description = "운동한 날짜 (started_at의 KST 날짜)") LocalDate workoutDate,
        @Schema(description = "시작 시각") OffsetDateTime startedAt,
        @Schema(description = "종료 시각. 진행 중이면 null") OffsetDateTime completedAt,
        @Schema(description = "소요 시간(초). 진행 중이면 null") Integer durationSec,
        @Schema(description = "상태. aborted는 6시간 넘게 끝나지 않아 서버가 자동 중단한 기록 (통계·미션에서 제외)") String status,
        @Schema(description = "완료(is_done) 세트 수") Integer setCount,
        @Schema(description = "완료 세트의 무게×횟수 합") BigDecimal totalVolumeKg
) {
}
