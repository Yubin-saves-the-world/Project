package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record ProductCreateRequest(
        @Schema(description = "제휴사 ID") @NotNull(message = "partner_id을(를) 입력해 주세요.") Long partnerId,
        @Schema(description = "분류") @NotNull(message = "category을(를) 입력해 주세요.") com.asdf.board.be.partner.entity.Product.Category category,
        @Schema(description = "상품명") @NotBlank(message = "name을(를) 입력해 주세요.") @Size(max = 100, message = "name 길이를 확인해 주세요.") String name,
        @Schema(description = "가격(원)") @Min(value = 0, message = "price 범위를 확인해 주세요.") Integer price,
        @Schema(description = "영양 정보") @Valid com.asdf.board.be.partner.dto.NutritionDto nutrition,
        @Schema(description = "판매 링크") @NotBlank(message = "link_url을(를) 입력해 주세요.") @Size(max = 500, message = "link_url 길이를 확인해 주세요.") String linkUrl,
        @Schema(description = "노출 시작") @NotNull(message = "display_from을(를) 입력해 주세요.") LocalDate displayFrom,
        @Schema(description = "노출 종료") @NotNull(message = "display_to을(를) 입력해 주세요.") LocalDate displayTo,
        @Schema(description = "광고·제휴 표시 여부 (기본 true)") Boolean isAdLabeled
) {
}
