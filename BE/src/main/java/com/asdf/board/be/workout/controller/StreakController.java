package com.asdf.board.be.workout.controller;

import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.workout.dto.StreakDto;
import com.asdf.board.be.workout.service.WorkoutStatsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "workout", description = "운동 종목 · 루틴 · 운동 기록")
@RestController
@RequestMapping("/api/streaks")
@RequiredArgsConstructor
public class StreakController {

    private final WorkoutStatsService statsService;

    @Operation(summary = "연속 운동일", description = "종료된 운동 기록이 있는 날을 운동한 날로 셉니다(KST). 오늘 아직 안 했어도 어제까지 이어졌으면 유지됩니다.")
    @GetMapping
    public StreakDto get(@AuthenticationPrincipal Jwt jwt) {
        return statsService.streak(CurrentUser.id(jwt));
    }
}
