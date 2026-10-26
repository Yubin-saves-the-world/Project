package com.asdf.board.be.partner.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record MissionProgressDto(
        @Schema(description = "미션 ID") Long missionId,
        @Schema(description = "현재 달성 횟수") Integer current,
        @Schema(description = "목표 횟수") Integer target,
        @Schema(description = "진행률(%)") Integer percent,
        @Schema(description = "달성 여부") Boolean completed
) {
}
