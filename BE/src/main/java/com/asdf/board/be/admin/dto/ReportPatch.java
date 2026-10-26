package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

public record ReportPatch(
        @Schema(description = "resolved 대상 숨김 유지 / rejected 숨김 해제") @NotNull(message = "status을(를) 입력해 주세요.") com.asdf.board.be.community.entity.Report.Status status
) {
}
