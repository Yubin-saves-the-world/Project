package com.asdf.board.be.partner.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record MissionDto(
        @Schema(description = "미션 ID") Long missionId,
        @Schema(description = "제목") String title,
        @Schema(description = "기간(일)") Integer periodDays,
        @Schema(description = "달성 기준 횟수") Integer targetCount,
        @Schema(description = "보상 이름. 없으면 null") String rewardTitle,
        @Schema(description = "시작") OffsetDateTime startsAt,
        @Schema(description = "종료") OffsetDateTime endsAt
) {
}
