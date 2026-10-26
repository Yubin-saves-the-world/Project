package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record ProductPatch(
        @Schema(description = "분류") com.asdf.board.be.partner.entity.Product.Category category,
        @Schema(description = "상품명") @Size(min = 1, max = 100, message = "name 길이를 확인해 주세요.") String name,
        @Schema(description = "가격(원)") @Min(value = 0, message = "price 범위를 확인해 주세요.") Integer price,
        @Schema(description = "영양 정보") @Valid com.asdf.board.be.partner.dto.NutritionDto nutrition,
        @Schema(description = "판매 링크") @Size(min = 1, max = 500, message = "link_url 길이를 확인해 주세요.") String linkUrl,
        @Schema(description = "노출 시작") LocalDate displayFrom,
        @Schema(description = "노출 종료") LocalDate displayTo,
        @Schema(description = "광고·제휴 표시 여부") Boolean isAdLabeled
) {
}
