package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record ReportDto(
        Long reportId,
        String targetType,
        Long targetId,
        String reason,
        @Schema(description = "상세 설명. 없으면 null") String detail,
        @Schema(description = "pending / resolved / rejected") String status,
        OffsetDateTime createdAt
) {
}
