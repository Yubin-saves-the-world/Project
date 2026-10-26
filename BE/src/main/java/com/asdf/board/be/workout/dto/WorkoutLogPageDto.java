package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record WorkoutLogPageDto(
        @Schema(description = "기간 요약") WorkoutSummaryDto summary,
        @Schema(description = "기록 목록 (started_at 내림차순)") List<WorkoutLogItemDto> items,
        @Schema(description = "현재 페이지") Integer page,
        @Schema(description = "페이지 크기") Integer pageSize,
        @Schema(description = "전체 개수") Integer total
) {
}
