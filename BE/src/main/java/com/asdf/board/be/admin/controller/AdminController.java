package com.asdf.board.be.admin.controller;

import com.asdf.board.be.admin.dto.*;
import com.asdf.board.be.admin.service.AdminService;
import com.asdf.board.be.community.entity.Report;
import com.asdf.board.be.correction.dto.CorrectionExerciseDetailDto;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.partner.dto.ProductDto;
import com.asdf.board.be.workout.dto.ExerciseDetailDto;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@Tag(name = "admin", description = "관리자")
@Validated
@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    @Operation(summary = "회원 목록")
    @GetMapping("/users")
    public AdminUserPageDto users(@RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return adminService.users(page, pageSize);
    }

    @Operation(summary = "회원 조회")
    @GetMapping("/users/{userId}")
    public AdminUserDto user(@PathVariable("userId") Long userId) {
        return adminService.user(userId);
    }

    @Operation(summary = "제휴사 목록")
    @GetMapping("/partners")
    public PartnerPageDto partners(@RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return adminService.partners(page, pageSize);
    }

    @Operation(summary = "제휴사 등록")
    @PostMapping("/partners")
    @ResponseStatus(HttpStatus.CREATED)
    public PartnerDto createPartner(@Valid @RequestBody PartnerRequest request) {
        return adminService.createPartner(request);
    }

    @Operation(summary = "제휴사 수정")
    @PatchMapping("/partners/{partnerId}")
    public PartnerDto patchPartner(@PathVariable("partnerId") Long partnerId, @Valid @RequestBody PartnerPatch request) {
        return adminService.patchPartner(partnerId, request);
    }

    @Operation(summary = "제휴 상품 등록")
    @PostMapping("/partner-products")
    @ResponseStatus(HttpStatus.CREATED)
    public ProductDto createProduct(@Valid @RequestBody ProductCreateRequest request) {
        return adminService.createProduct(request);
    }

    @Operation(summary = "제휴 상품 수정")
    @PatchMapping("/partner-products/{productId}")
    public ProductDto patchProduct(@PathVariable("productId") Long productId, @Valid @RequestBody ProductPatch request) {
        return adminService.patchProduct(productId, request);
    }

    @Operation(summary = "미션 등록")
    @PostMapping("/missions")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminMissionDto createMission(@Valid @RequestBody MissionCreateRequest request) {
        return adminService.createMission(request);
    }

    @Operation(summary = "미션 수정")
    @PatchMapping("/missions/{missionId}")
    public AdminMissionDto patchMission(@PathVariable("missionId") Long missionId, @Valid @RequestBody MissionPatchRequest request) {
        return adminService.patchMission(missionId, request);
    }

    @Operation(summary = "할인권 등록")
    @PostMapping("/coupons")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminCouponDto createCoupon(@Valid @RequestBody CouponCreateRequest request) {
        return adminService.createCoupon(request);
    }

    @Operation(summary = "할인권 수정")
    @PatchMapping("/coupons/{couponId}")
    public AdminCouponDto patchCoupon(@PathVariable("couponId") Long couponId, @Valid @RequestBody CouponPatch request) {
        return adminService.patchCoupon(couponId, request);
    }

    @Operation(summary = "운동 종목 등록")
    @PostMapping("/exercises")
    @ResponseStatus(HttpStatus.CREATED)
    public ExerciseDetailDto createExercise(@Valid @RequestBody ExerciseCreateRequest request) {
        return adminService.createExercise(request);
    }

    @Operation(summary = "운동 종목 수정")
    @PatchMapping("/exercises/{exerciseId}")
    public ExerciseDetailDto patchExercise(@PathVariable("exerciseId") Long exerciseId, @Valid @RequestBody ExercisePatch request) {
        return adminService.patchExercise(exerciseId, request);
    }

    @Operation(summary = "교정 운동 등록")
    @PostMapping("/correction-exercises")
    @ResponseStatus(HttpStatus.CREATED)
    public CorrectionExerciseDetailDto createCorrection(@Valid @RequestBody CorrectionCreateRequest request) {
        return adminService.createCorrection(request);
    }

    @Operation(summary = "교정 운동 수정")
    @PatchMapping("/correction-exercises/{correctionId}")
    public CorrectionExerciseDetailDto patchCorrection(@PathVariable("correctionId") Long correctionId, @Valid @RequestBody CorrectionPatch request) {
        return adminService.patchCorrection(correctionId, request);
    }

    @Operation(summary = "신고 목록")
    @GetMapping("/reports")
    public AdminReportPageDto reports(@RequestParam(value = "status", required = false) Report.Status status,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return adminService.reports(status, page, pageSize);
    }

    @Operation(summary = "신고 처리")
    @PatchMapping("/reports/{reportId}")
    public AdminReportDto patchReport(@AuthenticationPrincipal Jwt jwt, @PathVariable("reportId") Long reportId, @Valid @RequestBody ReportPatch request) {
        return adminService.patchReport(CurrentUser.id(jwt), reportId, request);
    }
}
