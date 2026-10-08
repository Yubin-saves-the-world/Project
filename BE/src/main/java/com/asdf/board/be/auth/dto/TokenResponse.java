package com.asdf.board.be.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record TokenResponse(
        @Schema(description = "JWT. Authorize 버튼에 붙여 넣어 사용") String accessToken,
        @Schema(example = "Bearer") String tokenType,
        @Schema(description = "만료까지 남은 초(7일)", example = "604800") long expiresIn,
        @Schema(description = "false면 앱이 신체정보(설문) 화면으로 이동") boolean onboardingCompleted
) {

    public static TokenResponse bearer(String accessToken, long expiresIn, boolean onboardingCompleted) {
        return new TokenResponse(accessToken, "Bearer", expiresIn, onboardingCompleted);
    }
}
