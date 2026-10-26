package com.asdf.board.be.workout.controller;

import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.workout.dto.SetPatch;
import com.asdf.board.be.workout.dto.SetRequest;
import com.asdf.board.be.workout.dto.WorkoutCompleteRequest;
import com.asdf.board.be.workout.dto.WorkoutCompletedDto;
import com.asdf.board.be.workout.dto.WorkoutLogDetailDto;
import com.asdf.board.be.workout.dto.WorkoutLogPageDto;
import com.asdf.board.be.workout.dto.WorkoutSetDto;
import com.asdf.board.be.workout.dto.WorkoutStartRequest;
import com.asdf.board.be.workout.dto.WorkoutStartedDto;
import com.asdf.board.be.workout.dto.WorkoutStatsDto;
import com.asdf.board.be.workout.service.WorkoutStatsService;
import com.asdf.board.be.workout.entity.WorkoutLog;
import com.asdf.board.be.workout.service.WorkoutService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.time.LocalDate;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
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
@Validated
@RestController
@RequestMapping("/api/workout-logs")
@RequiredArgsConstructor
public class WorkoutLogController {

    private final WorkoutService workoutService;
    private final WorkoutStatsService statsService;

    @Operation(summary = "운동 시작 (종목 1개)", description = "종목 하나를 실행할 때마다 기록 1개를 만듭니다. 같은 종목의 진행 중 기록이 있으면 새로 만들지 않고 그 기록을 200으로 돌려줍니다(resumed=true).")
    @PostMapping
    public ResponseEntity<WorkoutStartedDto> start(
            @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody WorkoutStartRequest request) {
        var result = workoutService.start(CurrentUser.id(jwt), request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK).body(result.body());
    }

    @Operation(summary = "운동 기록 조회", description = "summary는 페이지와 무관하게 조회 기간의 종료된 기록 전체 합계입니다. 기간은 최대 92일.")
    @GetMapping
    public WorkoutLogPageDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam("start_date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam("end_date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
            @RequestParam(value = "status", required = false) WorkoutLog.Status status,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return workoutService.list(CurrentUser.id(jwt), startDate, endDate, status, page, pageSize);
    }

    @Operation(summary = "운동 통계", description = "종료된 기록(completed)만 집계합니다. 기간은 최대 366일.")
    @GetMapping("/stats")
    public WorkoutStatsDto stats(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam("start_date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam("end_date") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        return statsService.stats(CurrentUser.id(jwt), startDate, endDate);
    }

    @Operation(summary = "운동 기록 상세")
    @GetMapping("/{logId}")
    public WorkoutLogDetailDto get(@AuthenticationPrincipal Jwt jwt, @PathVariable("logId") Long logId) {
        return workoutService.get(CurrentUser.id(jwt), logId);
    }

    @Operation(summary = "운동 기록 삭제", description = "진행 중인 기록 취소 또는 잘못된 기록 삭제. 세트도 함께 삭제합니다.")
    @DeleteMapping("/{logId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable("logId") Long logId) {
        workoutService.delete(CurrentUser.id(jwt), logId);
    }

    @Operation(summary = "세트 추가", description = "같은 client_set_id로 다시 호출하면 세트를 새로 만들지 않고 저장된 세트를 200으로 돌려줍니다. 진행 중 기록에만 추가할 수 있습니다.")
    @PostMapping("/{logId}/sets")
    public ResponseEntity<WorkoutSetDto> addSet(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("logId") Long logId, @Valid @RequestBody SetRequest request) {
        var result = workoutService.addSet(CurrentUser.id(jwt), logId, request);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK).body(result.body());
    }

    @Operation(summary = "세트 수정", description = "요청의 version이 서버 값과 다르면 VERSION_CONFLICT. 성공하면 version이 1 늘어납니다.")
    @PatchMapping("/{logId}/sets/{setId}")
    public WorkoutSetDto patchSet(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("logId") Long logId, @PathVariable("setId") Long setId,
            @Valid @RequestBody SetPatch request) {
        return workoutService.patchSet(CurrentUser.id(jwt), logId, setId, request);
    }

    @Operation(summary = "세트 삭제", description = "삭제해도 나머지 세트의 set_no는 다시 매기지 않습니다.")
    @DeleteMapping("/{logId}/sets/{setId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteSet(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("logId") Long logId, @PathVariable("setId") Long setId) {
        workoutService.deleteSet(CurrentUser.id(jwt), logId, setId);
    }

    @Operation(summary = "운동 종료", description = "완료 세트가 0개면 WORKOUT_EMPTY. 루틴의 모든 종목이 종료되면 루틴 status를 done으로 바꿉니다.")
    @PatchMapping("/{logId}/complete")
    public WorkoutCompletedDto complete(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("logId") Long logId,
            @Valid @RequestBody(required = false) WorkoutCompleteRequest request) {
        return workoutService.complete(CurrentUser.id(jwt), logId, request);
    }
}
