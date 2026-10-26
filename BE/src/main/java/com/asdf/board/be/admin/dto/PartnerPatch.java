package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record PartnerPatch(
        @Schema(description = "이름") @Size(min = 1, max = 50, message = "name 길이를 확인해 주세요.") String name,
        @Schema(description = "계약 시작") LocalDate contractStart,
        @Schema(description = "계약 종료") LocalDate contractEnd
) {
}
