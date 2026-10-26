package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record CouponPatch(
        @Schema(description = "이름") @Size(min = 1, max = 100, message = "title 길이를 확인해 주세요.") String title,
        @Schema(description = "할인 내용") @Size(min = 1, max = 200, message = "discount_desc 길이를 확인해 주세요.") String discountDesc,
        @Schema(description = "유효 일수") @Min(value = 1, message = "valid_days 범위를 확인해 주세요.") @Max(value = 365, message = "valid_days 범위를 확인해 주세요.") Integer validDays
) {
}
