package com.asdf.board.be.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Locale;

public record EmailCodeConfirmRequest(
        @Schema(description = "인증번호를 받은 이메일", example = "user@example.com")
        @NotBlank(message = "이메일을 입력해 주세요.")
        @Email(message = "이메일 형식이 올바르지 않습니다.")
        @Size(max = 255, message = "이메일은 255자 이하여야 합니다.")
        String email,

        @Schema(description = "메일로 받은 6자리 숫자", example = "123456")
        @NotBlank(message = "인증번호를 입력해 주세요.")
        @Pattern(regexp = "^\\d{6}$", message = "인증번호는 6자리 숫자예요.")
        String code
) {

    public EmailCodeConfirmRequest {
        email = email == null ? null : email.trim().toLowerCase(Locale.ROOT);
        code = code == null ? null : code.trim();
    }
}
