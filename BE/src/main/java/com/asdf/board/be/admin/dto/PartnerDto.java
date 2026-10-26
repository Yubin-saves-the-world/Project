package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;

public record PartnerDto(
        @Schema(description = "제휴사 ID") Long partnerId,
        @Schema(description = "이름") String name,
        @Schema(description = "계약 시작") LocalDate contractStart,
        @Schema(description = "계약 종료") LocalDate contractEnd
) {
}
