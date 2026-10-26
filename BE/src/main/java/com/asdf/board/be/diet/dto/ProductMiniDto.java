package com.asdf.board.be.diet.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record ProductMiniDto(
        @Schema(description = "상품 ID") Long productId,
        @Schema(description = "상품명") String name,
        @Schema(description = "구매 링크") String linkUrl,
        @Schema(description = "true면 광고·제휴 표시 필수") Boolean isAdLabeled
) {
}
