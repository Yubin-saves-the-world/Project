package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CouponCreateRequest(
        @Schema(description = "제휴사 ID") @NotNull(message = "partner_id을(를) 입력해 주세요.") Long partnerId,
        @Schema(description = "이름") @NotBlank(message = "title을(를) 입력해 주세요.") @Size(max = 100, message = "title 길이를 확인해 주세요.") String title,
        @Schema(description = "할인 내용") @NotBlank(message = "discount_desc을(를) 입력해 주세요.") @Size(max = 200, message = "discount_desc 길이를 확인해 주세요.") String discountDesc,
        @Schema(description = "발급 후 유효 일수") @NotNull(message = "valid_days을(를) 입력해 주세요.") @Min(value = 1, message = "valid_days 범위를 확인해 주세요.") @Max(value = 365, message = "valid_days 범위를 확인해 주세요.") Integer validDays
) {
}
