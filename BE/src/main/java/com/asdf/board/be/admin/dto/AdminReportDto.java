package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record AdminReportDto(
        @Schema(description = "신고 ID") Long reportId,
        @Schema(description = "대상 종류") String targetType,
        @Schema(description = "대상 ID") Long targetId,
        @Schema(description = "사유") String reason,
        @Schema(description = "상세") String detail,
        @Schema(description = "신고자") Long reporterId,
        @Schema(description = "처리 상태") String status,
        @Schema(description = "신고 시각") OffsetDateTime createdAt
) {
}
