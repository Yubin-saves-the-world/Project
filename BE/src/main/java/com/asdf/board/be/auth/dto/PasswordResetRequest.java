package com.asdf.board.be.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Locale;

public record PasswordResetRequest(
        @Schema(description = "가입한 이메일", example = "user@example.com")
        @NotBlank(message = "이메일을 입력해 주세요.")
        @Email(message = "이메일 형식이 올바르지 않습니다.")
        @Size(max = 255, message = "이메일은 255자 이하여야 합니다.")
        String email
) {

    public PasswordResetRequest {
        email = email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }
}
