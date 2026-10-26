package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import java.util.List;

public record RoutineDto(
        @Schema(description = "루틴 ID (하루 1개)") Long routineId,
        @Schema(description = "근거가 된 분석") Long analysisId,
        @Schema(description = "수행 예정일") LocalDate scheduledDate,
        @Schema(description = "제목") String title,
        @Schema(description = "주 부위") String targetPart,
        @Schema(description = "예상 소요 시간(분)") Integer estimatedMinutes,
        @Schema(description = "상태") String status,
        @Schema(description = "종목 목록 (order_no 순)") List<RoutineItemDto> items
) {
}
