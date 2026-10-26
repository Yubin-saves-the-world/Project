package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record WorkoutCompleteRequest(
        @Schema(description = "앱 타이머 값(초). 생략하면 서버가 종료 시각−시작 시각으로 계산. 경과 시간보다 크면 경과 시간으로 보정") @Min(value = 1, message = "duration_sec 범위를 확인해 주세요.") @Max(value = 21600, message = "duration_sec 범위를 확인해 주세요.") Integer durationSec,
        @Schema(description = "메모") @Size(min = 0, max = 255, message = "memo 길이를 확인해 주세요.") String memo
) {
}
