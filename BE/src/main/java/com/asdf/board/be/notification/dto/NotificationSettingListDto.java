package com.asdf.board.be.notification.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record NotificationSettingListDto(
        @Schema(description = "3종 모두") List<NotificationSettingDto> items
) {
}
