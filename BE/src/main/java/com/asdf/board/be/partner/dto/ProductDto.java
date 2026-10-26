package com.asdf.board.be.partner.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record ProductDto(
        @Schema(description = "상품 ID") Long productId,
        @Schema(description = "상품명") String name,
        @Schema(description = "가격(원). 모르면 null") Integer price,
        @Schema(description = "분류") String category,
        @Schema(description = "제휴사") String partnerName,
        @Schema(description = "영양 정보. 없으면 null") NutritionDto nutrition,
        @Schema(description = "판매 링크") String linkUrl,
        @Schema(description = "true면 광고·제휴 표시 필수") Boolean isAdLabeled
) {
}
