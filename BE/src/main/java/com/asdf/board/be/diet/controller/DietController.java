package com.asdf.board.be.diet.controller;

import com.asdf.board.be.diet.dto.DietCreateRequest;
import com.asdf.board.be.diet.dto.DietPlanDto;
import com.asdf.board.be.diet.dto.DietPlanListDto;
import com.asdf.board.be.diet.service.DietService;
import com.asdf.board.be.global.web.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "diet", description = "맞춤 식단")
@RestController
@RequestMapping("/api/diet-plans")
@RequiredArgsConstructor
public class DietController {

    private final DietService dietService;

    @Operation(summary = "맞춤 식단 생성", description = "BMR/TDEE로 목표 칼로리와 탄·단·지를 정하고 오늘부터 7일치 끼니별 식단을 만듭니다. 알레르기·제외 음식은 뺍니다. 오늘 이후 기존 식단은 교체합니다.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public DietPlanListDto create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody DietCreateRequest request) {
        return dietService.create(CurrentUser.id(jwt), request.analysisId());
    }

    @Operation(summary = "날짜별 식단 조회", description = "plan_date를 생략하면 오늘(KST). 없으면 DIET_NOT_FOUND.")
    @GetMapping
    public DietPlanDto getByDate(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "plan_date", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate planDate) {
        return dietService.getByDate(CurrentUser.id(jwt), planDate);
    }

    @Operation(summary = "식단 상세")
    @GetMapping("/{planId}")
    public DietPlanDto get(@AuthenticationPrincipal Jwt jwt, @PathVariable("planId") Long planId) {
        return dietService.get(CurrentUser.id(jwt), planId);
    }
}
