package com.asdf.board.be.diet.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record DietItemDto(
        Long dietItemId,
        @Schema(description = "음식 이름") String foodName,
        @Schema(description = "양") String amount,
        @Schema(description = "칼로리") Integer kcal,
        @Schema(description = "연결된 제휴 상품. 없으면 null") ProductMiniDto product
) {
}
