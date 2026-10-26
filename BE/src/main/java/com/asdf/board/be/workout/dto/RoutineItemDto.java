package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

public record RoutineItemDto(
        @Schema(description = "루틴 종목 ID") Long itemId,
        @Schema(description = "수행 순서 (1부터)") Integer orderNo,
        @Schema(description = "운동") ExerciseSummaryDto exercise,
        @Schema(description = "목표 세트") Integer targetSets,
        @Schema(description = "목표 횟수") Integer targetReps,
        @Schema(description = "목표 무게. 맨몸 운동이거나 개인 처방 근거가 없으면 null (몸무게만으로 중량을 만들어 넣지 않는다)") BigDecimal targetWeightKg,
        @Schema(description = "세트 간 휴식(초). 서버 고정 기본값이며 DB에 저장하지 않음") Integer restSec,
        @Schema(description = "이 종목을 넣은 이유. 없으면 null") String reason,
        @Schema(description = "이 루틴에서 이 종목의 운동 기록이 종료됐는지") Boolean done
) {
}
