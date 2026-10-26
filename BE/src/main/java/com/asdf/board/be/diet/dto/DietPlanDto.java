package com.asdf.board.be.diet.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;
import java.util.List;

public record DietPlanDto(
        @Schema(description = "식단 ID (하루 1개)") Long planId,
        @Schema(description = "날짜") LocalDate date,
        @Schema(description = "목표 칼로리") Integer targetKcal,
        @Schema(description = "탄수화물(g)") Integer carbG,
        @Schema(description = "단백질(g)") Integer proteinG,
        @Schema(description = "지방(g)") Integer fatG,
        @Schema(description = "끼니별 식단") List<MealDto> meals
) {
}
