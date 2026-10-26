package com.asdf.board.be.correction.controller;

import com.asdf.board.be.correction.dto.CorrectionExerciseDetailDto;
import com.asdf.board.be.correction.dto.CorrectionListDto;
import com.asdf.board.be.correction.entity.CorrectionExercise;
import com.asdf.board.be.correction.service.CorrectionService;
import com.asdf.board.be.global.web.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "correction", description = "자세 교정 운동")
@RestController
@RequestMapping("/api/correction-exercises")
@RequiredArgsConstructor
public class CorrectionController {

    private final CorrectionService correctionService;

    @Operation(summary = "교정 운동 목록", description = "최근 done 분석에서 caution인 항목의 교정 운동을 항목별 최대 3개 반환합니다. target_issue를 주면 판정과 무관하게 그 항목을 반환합니다.")
    @GetMapping
    public CorrectionListDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "target_issue", required = false) CorrectionExercise.TargetIssue targetIssue) {
        return correctionService.list(CurrentUser.id(jwt), targetIssue);
    }

    @Operation(summary = "교정 운동 상세")
    @GetMapping("/{correctionId}")
    public CorrectionExerciseDetailDto get(@AuthenticationPrincipal Jwt jwt, @PathVariable("correctionId") Long correctionId) {
        return correctionService.get(CurrentUser.id(jwt), correctionId);
    }
}
