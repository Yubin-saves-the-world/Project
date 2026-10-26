package com.asdf.board.be.body.controller;

import com.asdf.board.be.body.dto.GoalBodyDto;
import com.asdf.board.be.body.dto.GoalPatch;
import com.asdf.board.be.body.dto.GoalRequest;
import com.asdf.board.be.body.service.GoalBodyService;
import com.asdf.board.be.global.web.CurrentUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "goal", description = "목표 체형")
@RestController
@RequestMapping("/api/goal-bodies")
@RequiredArgsConstructor
public class GoalBodyController {

    private final GoalBodyService goalBodyService;

    @Operation(summary = "목표 체형 등록", description = "사진으로 등록하면 status=pending으로 돌려주고 AI가 특징을 뽑으면 done이 됩니다. 설명만 보내면 바로 done. 사용자당 1개.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public GoalBodyDto create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody GoalRequest request) {
        return goalBodyService.create(CurrentUser.id(jwt), request);
    }

    @Operation(summary = "목표 체형 조회", description = "앱은 pending이면 2초마다 조회합니다.")
    @GetMapping
    public GoalBodyDto get(@AuthenticationPrincipal Jwt jwt) {
        return goalBodyService.get(CurrentUser.id(jwt));
    }

    @Operation(summary = "목표 체형 수정", description = "새 사진을 보내면 pending으로 돌아가 특징을 다시 뽑습니다.")
    @PatchMapping("/{goalBodyId}")
    public GoalBodyDto update(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("goalBodyId") Long goalBodyId,
            @Valid @RequestBody GoalPatch request) {
        return goalBodyService.update(CurrentUser.id(jwt), goalBodyId, request);
    }

    @Operation(summary = "목표 체형 삭제", description = "처리 중인 목표 사진이 있으면 함께 삭제합니다.")
    @DeleteMapping("/{goalBodyId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable("goalBodyId") Long goalBodyId) {
        goalBodyService.delete(CurrentUser.id(jwt), goalBodyId);
    }
}
