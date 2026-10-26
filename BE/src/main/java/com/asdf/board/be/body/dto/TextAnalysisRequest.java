package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TextAnalysisRequest(
        @Schema(description = "체형 설명 (500자 이내)") @NotBlank(message = "text_input을(를) 입력해 주세요.") @Size(min = 1, max = 500, message = "text_input 길이를 확인해 주세요.") String textInput
) {
}
