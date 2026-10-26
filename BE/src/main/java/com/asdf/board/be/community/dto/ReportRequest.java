package com.asdf.board.be.community.dto;

import com.asdf.board.be.community.entity.Report;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ReportRequest(
        @Schema(description = "신고 대상 종류") @NotNull(message = "target_type을(를) 입력해 주세요.") Report.TargetType targetType,
        @Schema(description = "신고 대상 ID") @NotNull(message = "target_id을(를) 입력해 주세요.") Long targetId,
        @Schema(description = "사유") @NotNull(message = "reason을(를) 입력해 주세요.") Report.Reason reason,
        @Schema(description = "상세 설명") @Size(max = 200, message = "detail 길이를 확인해 주세요.") String detail
) {
}
