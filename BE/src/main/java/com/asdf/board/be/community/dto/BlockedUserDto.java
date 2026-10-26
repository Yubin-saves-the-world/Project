package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record BlockedUserDto(
        @Schema(description = "차단한 사용자 ID") Long userId,
        @Schema(description = "닉네임") String nickname,
        @Schema(description = "차단 시각") OffsetDateTime createdAt
) {
}
