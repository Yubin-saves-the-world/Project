package com.asdf.board.be.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record EmailVerificationTokenResponse(
        @Schema(description = "회원가입 요청의 email_verification_token에 넣는 값. 한 번만 쓸 수 있음")
        String verificationToken,
        @Schema(description = "토큰 유효 시간(초)", example = "1800")
        long expiresIn
) {
}
