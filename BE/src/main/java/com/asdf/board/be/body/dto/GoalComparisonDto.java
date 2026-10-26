package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record GoalComparisonDto(
        @Schema(description = "집중 부위 1~3개, 우선순위 순") List<BodyPartDto> priorityParts,
        @Schema(description = "한 문장 요약(60자 이내)") String summary,
        @Schema(description = "두세 문장 설명 (AI 소견)") String detail
) {
}
