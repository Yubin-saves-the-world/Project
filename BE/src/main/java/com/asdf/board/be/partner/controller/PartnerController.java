package com.asdf.board.be.partner.controller;

import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.partner.dto.MissionDto;
import com.asdf.board.be.partner.dto.MissionProgressDto;
import com.asdf.board.be.partner.dto.ProductDto;
import com.asdf.board.be.partner.dto.ProductPageDto;
import com.asdf.board.be.partner.dto.UserCouponDto;
import com.asdf.board.be.partner.dto.UserCouponPageDto;
import com.asdf.board.be.partner.entity.Product;
import com.asdf.board.be.partner.entity.UserCoupon;
import com.asdf.board.be.partner.service.PartnerService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "partner", description = "제휴 상품 · 미션 · 할인권")
@Validated
@RestController
@RequiredArgsConstructor
public class PartnerController {

    private final PartnerService partnerService;

    @Operation(summary = "제휴 상품 목록", description = "노출 기간 안의 상품만. is_ad_labeled=true면 광고·제휴 표시 필수.")
    @GetMapping("/api/partner-products")
    public ProductPageDto products(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "category", required = false) Product.Category category,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return partnerService.products(CurrentUser.id(jwt), category, page, pageSize);
    }

    @Operation(summary = "제휴 상품 상세")
    @GetMapping("/api/partner-products/{productId}")
    public ProductDto product(@AuthenticationPrincipal Jwt jwt, @PathVariable("productId") Long productId) {
        return partnerService.product(CurrentUser.id(jwt), productId);
    }

    @Operation(summary = "현재 미션", description = "is_active=true인 미션 중 가장 최근 1개. 처음 조회하면 이 사용자의 미션이 시작됩니다. 없으면 NO_ACTIVE_MISSION.")
    @GetMapping("/api/missions/current")
    public MissionDto currentMission(@AuthenticationPrincipal Jwt jwt) {
        return partnerService.currentMission(CurrentUser.id(jwt));
    }

    @Operation(summary = "미션 진행률", description = "종료된 운동 기록으로 서버가 계산합니다. 달성하면 할인권을 자동 발급합니다.")
    @GetMapping("/api/missions/{missionId}/progress")
    public MissionProgressDto progress(@AuthenticationPrincipal Jwt jwt, @PathVariable("missionId") Long missionId) {
        return partnerService.progress(CurrentUser.id(jwt), missionId);
    }

    @Operation(summary = "내 할인권 목록")
    @GetMapping("/api/user-coupons")
    public UserCouponPageDto coupons(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "status", required = false) UserCoupon.Status status,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return partnerService.coupons(CurrentUser.id(jwt), status, page, pageSize);
    }

    @Operation(summary = "내 할인권 상세")
    @GetMapping("/api/user-coupons/{userCouponId}")
    public UserCouponDto coupon(@AuthenticationPrincipal Jwt jwt, @PathVariable("userCouponId") Long userCouponId) {
        return partnerService.coupon(CurrentUser.id(jwt), userCouponId);
    }
}
