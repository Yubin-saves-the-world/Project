package com.asdf.board.be.coach.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

public record SuggestionConfirmRequest(
        @Schema(description = "true 적용 / false 거절") @NotNull(message = "confirmed을(를) 입력해 주세요.") Boolean confirmed
) {
}
