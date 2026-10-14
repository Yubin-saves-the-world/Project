package com.asdf.board.be.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record PasswordResetTokenResponse(
        @Schema(description = "비밀번호 재설정 요청의 token에 넣는 값. 한 번만 쓸 수 있음")
        String resetToken,
        @Schema(description = "토큰 유효 시간(초)", example = "1800")
        long expiresIn
) {
}
