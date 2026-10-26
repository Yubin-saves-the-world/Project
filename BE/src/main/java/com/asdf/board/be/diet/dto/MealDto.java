package com.asdf.board.be.diet.dto;

import java.util.List;

public record MealDto(
        String mealType,
        Integer totalKcal,
        List<DietItemDto> items
) {
}
