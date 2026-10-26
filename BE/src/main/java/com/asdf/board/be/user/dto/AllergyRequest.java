package com.asdf.board.be.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AllergyRequest(
        @Schema(description = "알레르기 또는 먹지 않는 음식") @NotBlank(message = "item을(를) 입력해 주세요.") @Size(min = 1, max = 30, message = "item 길이를 확인해 주세요.") String item
) {
}
