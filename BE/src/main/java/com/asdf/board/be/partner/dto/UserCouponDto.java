package com.asdf.board.be.partner.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDate;

public record UserCouponDto(
        @Schema(description = "보유 할인권 ID") Long userCouponId,
        @Schema(description = "이름") String title,
        @Schema(description = "할인 내용") String discountDesc,
        @Schema(description = "제휴사") String partnerName,
        @Schema(description = "available / used / expired") String status,
        @Schema(description = "유효기간 마지막 날") LocalDate validUntil
) {
}
