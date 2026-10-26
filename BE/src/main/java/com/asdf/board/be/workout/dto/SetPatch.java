package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record SetPatch(
        @Schema(description = "마지막으로 받은 세트의 version. 서버 값과 다르면 VERSION_CONFLICT") @NotNull(message = "version을(를) 입력해 주세요.") Integer version,
        @Schema(description = "무게") @DecimalMin(value = "0", message = "weight_kg 범위를 확인해 주세요.") @DecimalMax(value = "500", message = "weight_kg 범위를 확인해 주세요.") BigDecimal weightKg,
        @Schema(description = "횟수") @Min(value = 1, message = "reps 범위를 확인해 주세요.") @Max(value = 100, message = "reps 범위를 확인해 주세요.") Integer reps,
        @Schema(description = "완료 여부") Boolean isDone,
        @Schema(description = "실제 쉰 시간(초)") @Min(value = 0, message = "rest_sec 범위를 확인해 주세요.") @Max(value = 3600, message = "rest_sec 범위를 확인해 주세요.") Integer restSec
) {
}
