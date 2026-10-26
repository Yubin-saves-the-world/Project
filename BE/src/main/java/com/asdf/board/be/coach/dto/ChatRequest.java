package com.asdf.board.be.coach.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChatRequest(
        @Schema(description = "질문 (500자 이내)") @NotBlank(message = "content을(를) 입력해 주세요.") @Size(min = 1, max = 500, message = "content 길이를 확인해 주세요.") String content
) {
}
