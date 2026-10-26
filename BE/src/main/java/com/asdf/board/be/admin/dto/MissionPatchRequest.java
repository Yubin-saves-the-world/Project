package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import java.util.Map;

public record MissionPatchRequest(
        @Schema(description = "제목") @Size(min = 1, max = 100, message = "title 길이를 확인해 주세요.") String title,
        @Schema(description = "달성 조건") Map<String, Object> conditionJson,
        @Schema(description = "기간(일)") @Min(value = 1, message = "period_days 범위를 확인해 주세요.") @Max(value = 90, message = "period_days 범위를 확인해 주세요.") Integer periodDays,
        @Schema(description = "보상 할인권") Long couponId,
        @Schema(description = "현재 미션 후보 여부") Boolean isActive
) {
}
