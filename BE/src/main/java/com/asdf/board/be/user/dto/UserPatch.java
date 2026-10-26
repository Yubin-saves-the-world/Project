package com.asdf.board.be.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;

public record UserPatch(
        @Schema(description = "새 닉네임 (2~20자)")
        @Size(min = 2, max = 20, message = "닉네임은 2~20자여야 합니다.")
        String nickname,
        @Schema(description = "true만 허용 (철회는 회원 탈퇴)") Boolean termsAgreed,
        @Schema(description = "true만 허용") Boolean privacyAgreed,
        @Schema(description = "true 동의 / false 철회") Boolean bodyPhotoAgreed,
        @Schema(description = "true 동의 / false 철회") Boolean aiProcessingAgreed
) {

    public UserPatch {
        nickname = nickname == null ? null : nickname.trim();
    }

    public boolean isEmpty() {
        return nickname == null && termsAgreed == null && privacyAgreed == null
                && bodyPhotoAgreed == null && aiProcessingAgreed == null;
    }
}
