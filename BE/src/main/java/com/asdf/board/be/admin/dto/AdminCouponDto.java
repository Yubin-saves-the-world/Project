package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record AdminCouponDto(
        @Schema(description = "할인권 ID") Long couponId,
        @Schema(description = "제휴사 ID") Long partnerId,
        @Schema(description = "이름") String title,
        @Schema(description = "할인 내용") String discountDesc,
        @Schema(description = "유효 일수") Integer validDays
) {
}
