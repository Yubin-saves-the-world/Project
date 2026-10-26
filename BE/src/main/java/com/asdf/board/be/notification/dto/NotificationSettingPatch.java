package com.asdf.board.be.notification.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record NotificationSettingPatch(
        @Schema(description = "켜짐 여부") Boolean enabled,
        @Schema(description = "알림 시각 (HH:mm)") String time
) {
}
