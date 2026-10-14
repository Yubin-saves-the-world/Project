package com.asdf.board.be.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PasswordResetConfirmRequest(
        @Schema(description = "인증번호 확인 응답의 reset_token", example = "3f9a1c7e5b2d4a8f9e0c1b2a3d4e5f60")
        @NotBlank(message = "재설정 토큰이 필요합니다.")
        @Size(max = 200, message = "재설정 토큰이 올바르지 않습니다.")
        String token,

        @Schema(description = "8~64자, 영문과 숫자를 각각 1자 이상 포함", example = "abcd1234")
        @NotBlank(message = "새 비밀번호를 입력해 주세요.")
        @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).{8,64}$", message = "8자 이상 영문+숫자 조합이어야 합니다.")
        String newPassword
) {

    public PasswordResetConfirmRequest {
        token = token == null ? null : token.trim();
    }
}
