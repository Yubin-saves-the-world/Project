package com.asdf.board.be.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record AllergyDto(
        @Schema(description = "ID") Long allergyId,
        @Schema(description = "알레르기 또는 먹지 않는 음식") String item,
        @Schema(description = "등록 시각") OffsetDateTime createdAt
) {
}
