package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

public record RoutineCreateRequest(
        @Schema(description = "근거로 쓸 분석 (status=done)") @NotNull(message = "analysis_id을(를) 입력해 주세요.") Long analysisId
) {
}
