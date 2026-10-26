package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;

public record WorkoutSetDto(
        @Schema(description = "세트 ID") Long setId,
        @Schema(description = "앱이 만든 UUID. 같은 값으로 다시 보내도 세트가 두 번 만들어지지 않음") String clientSetId,
        @Schema(description = "세트 번호 (1부터)") Integer setNo,
        @Schema(description = "수정할 때마다 1씩 늘어나는 값. 세트 수정 요청에 그대로 보냄") Integer version,
        @Schema(description = "무게") BigDecimal weightKg,
        @Schema(description = "횟수") Integer reps,
        @Schema(description = "실제 쉰 시간(초). 기록 안 했으면 null") Integer restSec,
        @Schema(description = "완료 여부") Boolean isDone
) {
}
