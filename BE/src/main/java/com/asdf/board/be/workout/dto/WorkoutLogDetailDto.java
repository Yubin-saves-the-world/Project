package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public record WorkoutLogDetailDto(
        @Schema(description = "운동 기록 ID") Long logId,
        @Schema(description = "종목") ExerciseMiniDto exercise,
        @Schema(description = "루틴에서 시작했으면 루틴 ID") Long routineId,
        @Schema(description = "운동한 날짜 (started_at의 KST 날짜)") LocalDate workoutDate,
        @Schema(description = "시작 시각") OffsetDateTime startedAt,
        @Schema(description = "종료 시각. 진행 중이면 null") OffsetDateTime completedAt,
        @Schema(description = "소요 시간(초). 진행 중이면 null") Integer durationSec,
        @Schema(description = "상태") String status,
        @Schema(description = "완료(is_done) 세트 수") Integer setCount,
        @Schema(description = "완료 세트의 무게×횟수 합") BigDecimal totalVolumeKg,
        @Schema(description = "메모. 없으면 null") String memo,
        @Schema(description = "세트 목록 (set_no 순)") List<WorkoutSetDto> sets
) {
}
