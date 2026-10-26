package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record GoalBodyDto(
        @Schema(description = "목표 체형 ID") Long goalBodyId,
        @Schema(description = "사진 목표는 pending에서 시작해 AI가 특징을 뽑으면 done. 설명만 있는 목표는 바로 done") String status,
        @Schema(description = "AI가 목표 사진에서 뽑은 특징 요약. 사진을 보관하지 않으므로 비교에는 이 문장과 설명을 쓴다. 설명만 있는 목표는 null") String summary,
        @Schema(description = "status=failed일 때 사용자에게 보여줄 문장") String errorMessage,
        @Schema(description = "status=pending일 때 다음 조회까지 권장 대기(ms)") Integer pollAfterMs,
        @Schema(description = "설명. 없으면 null") String description,
        @Schema(description = "등록 시각") OffsetDateTime createdAt
) {
}
