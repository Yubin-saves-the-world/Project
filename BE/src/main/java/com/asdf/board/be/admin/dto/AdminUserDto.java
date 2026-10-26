package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record AdminUserDto(
        @Schema(description = "회원 ID") Long userId,
        @Schema(description = "이메일") String email,
        @Schema(description = "닉네임") String nickname,
        @Schema(description = "권한") String role,
        @Schema(description = "신체정보 입력 완료 여부") Boolean onboardingCompleted,
        @Schema(description = "가입 시각") OffsetDateTime createdAt,
        @Schema(description = "탈퇴 시각") OffsetDateTime deletedAt
) {
}
