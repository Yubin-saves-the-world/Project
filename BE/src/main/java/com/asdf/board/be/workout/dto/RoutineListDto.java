package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record RoutineListDto(
        @Schema(description = "근거 분석") Long analysisId,
        @Schema(description = "생성된 루틴 (오늘부터 7일 중 운동일)") List<RoutineDto> routines
) {
}
