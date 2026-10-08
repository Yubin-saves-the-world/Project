package com.asdf.board.be.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Locale;

public record SignupRequest(
        @NotBlank(message = "이메일을 입력해 주세요.")
        @Email(message = "이메일 형식이 올바르지 않습니다.")
        @Size(max = 255, message = "이메일은 255자 이하여야 합니다.")
        @Schema(description = "이메일. 소문자로 저장·비교", example = "user@example.com")
        String email,

        @NotBlank(message = "비밀번호를 입력해 주세요.")
        @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).{8,64}$", message = "8자 이상 영문+숫자 조합이어야 합니다.")
        @Schema(description = "8~64자, 영문과 숫자를 각각 1자 이상 포함", example = "abcd1234")
        String password,

        @NotBlank(message = "닉네임을 입력해 주세요.")
        @Size(min = 2, max = 20, message = "닉네임은 2~20자여야 합니다.")
        @Schema(description = "닉네임 2~20자", example = "지한")
        String nickname,

        @Schema(description = "이용약관 동의 (true 필수)", example = "true")
        @NotNull(message = "이용약관 동의 여부가 필요합니다.") Boolean termsAgreed,

        @Schema(description = "개인정보 처리방침 동의 (true 필수)", example = "true")
        @NotNull(message = "개인정보 처리방침 동의 여부가 필요합니다.") Boolean privacyAgreed,

        @Schema(description = "신체 사진 수집·이용 동의 (true 필수)", example = "true")
        @NotNull(message = "신체 사진 수집·이용 동의 여부가 필요합니다.") Boolean bodyPhotoAgreed,

        @Schema(description = "AI 분석 처리 동의 (true 필수)", example = "true")
        @NotNull(message = "AI 분석 처리 동의 여부가 필요합니다.") Boolean aiProcessingAgreed,


        @Size(min = 1, max = 30, message = "약관 버전은 1~30자여야 합니다.")
        @Schema(description = "동의한 약관 버전. 생략하면 서버의 현재 버전", example = "2026-10-01")
        String policyVersion
) {

    public SignupRequest {
        email = email == null ? null : email.trim().toLowerCase(Locale.ROOT);
        nickname = nickname == null ? null : nickname.trim();
    }

    public boolean allConsentsAgreed() {
        return Boolean.TRUE.equals(termsAgreed)
                && Boolean.TRUE.equals(privacyAgreed)
                && Boolean.TRUE.equals(bodyPhotoAgreed)
                && Boolean.TRUE.equals(aiProcessingAgreed);
    }
}
