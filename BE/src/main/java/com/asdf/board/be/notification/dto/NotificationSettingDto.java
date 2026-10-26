package com.asdf.board.be.notification.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record NotificationSettingDto(
        @Schema(description = "workout / diet / streak_risk") String type,
        @Schema(description = "켜짐 여부") Boolean enabled,
        @Schema(description = "알림 시각(HH:mm). streak_risk는 서버 고정이라 null") String time
) {
}
