package com.asdf.board.be.workout.controller;

import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.workout.dto.RoutineCreateRequest;
import com.asdf.board.be.workout.dto.RoutineDto;
import com.asdf.board.be.workout.dto.RoutineListDto;
import com.asdf.board.be.workout.dto.RoutinePatch;
import com.asdf.board.be.workout.dto.RoutineTodayDto;
import com.asdf.board.be.workout.dto.RoutineWeekDto;
import com.asdf.board.be.workout.service.RoutineService;
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
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "workout", description = "운동 종목 · 루틴 · 운동 기록")
@RestController
@RequestMapping("/api/routines")
@RequiredArgsConstructor
public class RoutineController {

    private final RoutineService routineService;

    @Operation(summary = "맞춤 루틴 생성", description = "오늘부터 7일 중 weekly_frequency일을 골라 하루 1개씩 루틴을 만듭니다. 오늘 이후 planned 루틴은 새로 만든 것으로 교체하고 done·skipped는 유지합니다.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public RoutineListDto create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody RoutineCreateRequest request) {
        return routineService.create(CurrentUser.id(jwt), request.analysisId());
    }

    @Operation(summary = "주간 루틴 조회", description = "항상 월~일 7칸을 반환합니다. week_start는 월요일이어야 합니다(생략하면 이번 주).")
    @GetMapping("/weekly")
    public RoutineWeekDto weekly(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "week_start", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate weekStart) {
        return routineService.weekly(CurrentUser.id(jwt), weekStart);
    }

    @Operation(summary = "오늘의 루틴", description = "루틴이 없으면 is_rest_day=true, routine=null (에러가 아님).")
    @GetMapping("/today")
    public RoutineTodayDto today(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "date", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return routineService.today(CurrentUser.id(jwt), date);
    }

    @Operation(summary = "루틴 상세")
    @GetMapping("/{routineId}")
    public RoutineDto get(@AuthenticationPrincipal Jwt jwt, @PathVariable("routineId") Long routineId) {
        return routineService.get(CurrentUser.id(jwt), routineId);
    }

    @Operation(summary = "루틴 건너뛰기·되돌리기", description = "planned를 skipped로 건너뛰거나, skipped를 planned로 되돌립니다(오늘 이후 날짜만). 이미 done이면 VALIDATION_FAILED. 같은 상태로 다시 보내도 오류가 아닙니다.")
    @PatchMapping("/{routineId}")
    public RoutineDto patch(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("routineId") Long routineId, @Valid @RequestBody RoutinePatch request) {
        return routineService.changeStatus(CurrentUser.id(jwt), routineId, request.status());
    }
}
