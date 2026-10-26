package com.asdf.board.be.coach.controller;

import com.asdf.board.be.coach.dto.AiUsageDto;
import com.asdf.board.be.coach.dto.ChatMessagePageDto;
import com.asdf.board.be.coach.dto.ChatRequest;
import com.asdf.board.be.coach.dto.ChatResponseDto;
import com.asdf.board.be.coach.dto.SuggestionConfirmRequest;
import com.asdf.board.be.coach.dto.SuggestionConfirmedDto;
import com.asdf.board.be.coach.service.CoachService;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "coach", description = "AI 코치")
@Validated
@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
public class CoachController {

    private final CoachService coachService;

    @Operation(summary = "AI 코치에게 질문", description = "동기 응답. AI_UNAVAILABLE이면 질문을 저장하지 않고 횟수도 차감하지 않습니다. 루틴 변경은 suggestion을 confirm해야만 반영됩니다.")
    @PostMapping("/chat")
    public ChatResponseDto ask(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ChatRequest request) {
        return coachService.ask(CurrentUser.id(jwt), request.content());
    }

    @Operation(summary = "AI 대화 기록", description = "최신순.")
    @GetMapping("/chat")
    public ChatMessagePageDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return coachService.list(CurrentUser.id(jwt), page, pageSize);
    }

    @Operation(summary = "AI 코치 사용량", description = "초기화는 KST 자정.")
    @GetMapping("/usage")
    public AiUsageDto usage(@AuthenticationPrincipal Jwt jwt) {
        return coachService.usage(CurrentUser.id(jwt));
    }

    @Operation(summary = "루틴 수정 제안 확인", description = "confirmed=true일 때만 오늘 이후 planned 루틴에 적용합니다. false면 폐기(dismissed).")
    @PostMapping("/routine-suggestions/{suggestionId}/confirm")
    public SuggestionConfirmedDto confirm(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("suggestionId") Long suggestionId,
            @Valid @RequestBody SuggestionConfirmRequest request) {
        return coachService.confirm(CurrentUser.id(jwt), suggestionId, request.confirmed());
    }
}
