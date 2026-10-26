package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;

public record RoutineSummaryDto(
        @Schema(description = "루틴 ID") Long routineId,
        @Schema(description = "수행 예정일") LocalDate scheduledDate,
        @Schema(description = "제목") String title,
        @Schema(description = "주 부위") String targetPart,
        @Schema(description = "예상 소요 시간(분)") Integer estimatedMinutes,
        @Schema(description = "상태") String status,
        @Schema(description = "종목 수") Integer itemCount,
        @Schema(description = "완료한 종목 수") Integer doneCount
) {
}
