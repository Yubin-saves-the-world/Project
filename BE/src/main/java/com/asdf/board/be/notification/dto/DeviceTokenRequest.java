package com.asdf.board.be.notification.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record DeviceTokenRequest(
        @Schema(description = "FCM 등록 토큰") @NotBlank(message = "fcm_token을(를) 입력해 주세요.") @Size(max = 4096, message = "fcm_token 길이를 확인해 주세요.") String fcmToken,
        @Schema(description = "플랫폼") @NotNull(message = "platform을(를) 입력해 주세요.") com.asdf.board.be.notification.entity.DeviceToken.Platform platform
) {
}
