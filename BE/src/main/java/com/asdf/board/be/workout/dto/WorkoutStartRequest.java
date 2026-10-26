package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

public record WorkoutStartRequest(
        @Schema(description = "시작할 종목") @NotNull(message = "exercise_id을(를) 입력해 주세요.") Long exerciseId,
        @Schema(description = "루틴에서 시작하면 루틴 ID. 자유 운동이면 생략") Long routineId
) {
}
