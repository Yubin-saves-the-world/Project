package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.Map;

public record MissionCreateRequest(
        @Schema(description = "제목") @NotBlank(message = "title을(를) 입력해 주세요.") @Size(max = 100, message = "title 길이를 확인해 주세요.") String title,
        @Schema(description = "달성 조건. 예: {\"type\":\"workout_days\",\"count\":3}") @NotNull(message = "condition_json을(를) 입력해 주세요.") Map<String, Object> conditionJson,
        @Schema(description = "기간(일)") @NotNull(message = "period_days을(를) 입력해 주세요.") @Min(value = 1, message = "period_days 범위를 확인해 주세요.") @Max(value = 90, message = "period_days 범위를 확인해 주세요.") Integer periodDays,
        @Schema(description = "달성 보상 할인권") Long couponId,
        @Schema(description = "현재 미션 후보 여부 (기본 true)") Boolean isActive
) {
}
