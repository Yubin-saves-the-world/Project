package com.asdf.board.be.workout.controller;

import com.asdf.board.be.global.enums.TargetPart;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.workout.dto.ExercisePageDto;
import com.asdf.board.be.workout.dto.ExerciseDetailDto;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.service.ExerciseService;
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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "workout", description = "운동 종목 · 루틴 · 운동 기록")
@Validated
@RestController
@RequestMapping("/api/exercises")
@RequiredArgsConstructor
public class ExerciseController {

    private final ExerciseService exerciseService;

    @Operation(summary = "운동 목록", description = "이름 오름차순. min_sets·max_sets는 요청한 사용자의 경력 기준 처방입니다.")
    @GetMapping
    public ExercisePageDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "target_part", required = false) TargetPart targetPart,
            @RequestParam(value = "difficulty", required = false)
            @Min(value = 1, message = "difficulty는 1~5입니다.") @Max(value = 5, message = "difficulty는 1~5입니다.") Integer difficulty,
            @RequestParam(value = "equipment", required = false) Exercise.Equipment equipment,
            @RequestParam(value = "q", required = false) String q,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return exerciseService.list(CurrentUser.id(jwt), targetPart, difficulty, equipment, q, page, pageSize);
    }

    @Operation(summary = "운동 상세")
    @GetMapping("/{exerciseId}")
    public ExerciseDetailDto get(@AuthenticationPrincipal Jwt jwt, @PathVariable("exerciseId") Long exerciseId) {
        return exerciseService.get(CurrentUser.id(jwt), exerciseId);
    }
}
