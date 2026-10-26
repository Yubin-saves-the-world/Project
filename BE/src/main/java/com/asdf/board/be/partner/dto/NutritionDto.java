package com.asdf.board.be.partner.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record NutritionDto(
        @Schema(description = "칼로리") Integer kcal,
        @Schema(description = "탄수화물(g)") Integer carbG,
        @Schema(description = "단백질(g)") Integer proteinG,
        @Schema(description = "지방(g)") Integer fatG
) {
}
