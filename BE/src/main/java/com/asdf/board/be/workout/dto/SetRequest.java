package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record SetRequest(
        @Schema(description = "앱이 세트마다 만드는 UUID. 네트워크 재시도 때 같은 값을 다시 보냄") @NotBlank(message = "client_set_id을(를) 입력해 주세요.") @Size(min = 36, max = 1000000, message = "client_set_id 길이를 확인해 주세요.") String clientSetId,
        @Schema(description = "세트 번호") @NotNull(message = "set_no을(를) 입력해 주세요.") @Min(value = 1, message = "set_no 범위를 확인해 주세요.") @Max(value = 20, message = "set_no 범위를 확인해 주세요.") Integer setNo,
        @Schema(description = "무게. 맨몸 운동은 0") @NotNull(message = "weight_kg을(를) 입력해 주세요.") @DecimalMin(value = "0", message = "weight_kg 범위를 확인해 주세요.") @DecimalMax(value = "500", message = "weight_kg 범위를 확인해 주세요.") BigDecimal weightKg,
        @Schema(description = "횟수") @NotNull(message = "reps을(를) 입력해 주세요.") @Min(value = 1, message = "reps 범위를 확인해 주세요.") @Max(value = 100, message = "reps 범위를 확인해 주세요.") Integer reps,
        @Schema(description = "완료 여부. 생략하면 true") Boolean isDone,
        @Schema(description = "실제 쉰 시간(초)") @Min(value = 0, message = "rest_sec 범위를 확인해 주세요.") @Max(value = 3600, message = "rest_sec 범위를 확인해 주세요.") Integer restSec
) {
}
