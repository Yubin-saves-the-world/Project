package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.Map;

public record AdminMissionDto(
        @Schema(description = "미션 ID") Long missionId,
        @Schema(description = "제목") String title,
        @Schema(description = "달성 조건") Map<String, Object> conditionJson,
        @Schema(description = "기간(일)") Integer periodDays,
        @Schema(description = "보상 할인권") Long couponId,
        @Schema(description = "현재 미션 후보 여부") Boolean isActive
) {
}
